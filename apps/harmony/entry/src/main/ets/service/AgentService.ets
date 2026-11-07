import {
  Action,
  ActionExecutor,
  ActionOutcome,
  AgentLoop,
  AnthropicClient,
  ApprovalGateway,
  ApprovalPolicy,
  BatchItemResult,
  BatchRunner,
  GeminiClient,
  ModelClient,
  ModelRequest,
  ModelResponse,
  OpenAiCompatibleClient,
  RiskLevel,
  RunRecord,
  RunStore,
  ScheduleBook,
  ScheduledTask,
  Screen,
  ScreenSource,
  ToolDescriptor,
  ToolRegistry
} from '@hopa/core';
import { WebCapability } from '@hopa/capability-web';
import { SandboxCapability } from '@hopa/capability-sandbox';
import { A11yBridge, A11yCapability, UiCapability, UiLauncher } from '@hopa/capability-a11y';
import { SystemCapability } from '@hopa/capability-system';
import { Context, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BrowserController } from './BrowserController';
import { BackgroundKeeper } from './BackgroundKeeper';
import { APP_CATALOG, CatalogApp } from './AppCatalog';
import { RemoteBridge } from './RemoteBridge';
import { RemoteScreenSource, RemoteUiCapability } from './RemoteUiCapability';
import { MemoryItem, MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';
import { Skill } from '@hopa/core';
import { SkillDraft, SkillDrafter } from '@hopa/core';

/** Called when an action needs the user's decision. Must be fail-closed. */
export type ApprovalPrompt = (action: Action, screen: Screen | undefined) => Promise<boolean>;

/** Adds coarse timing breadcrumbs to the model call (hilog tag HOPA). */
class LoggedModelClient implements ModelClient {
  private inner: ModelClient;

  constructor(inner: ModelClient) {
    this.inner = inner;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    hilog.info(0x0000, 'HOPA', `model: start messages=${request.messages.length}`);
    try {
      const response: ModelResponse = await this.inner.complete(request);
      hilog.info(
        0x0000,
        'HOPA',
        `model: done tokens=${response.tokens} error=${response.error.length}`
      );
      return response;
    } catch (error) {
      hilog.error(0x0000, 'HOPA', `model: threw ${error}`);
      throw new Error(`${error}`);
    }
  }
}

/**
 * Approval gateway backed by the ArkUI sheet. Until the page installs a
 * handler, every request is denied: the default is never "allow".
 */
export class UiApprovalGateway implements ApprovalGateway {
  private handler: ApprovalPrompt | undefined = undefined;

  setHandler(handler: ApprovalPrompt | undefined): void {
    this.handler = handler;
  }

  async requestApproval(action: Action, screen?: Screen): Promise<boolean> {
    if (this.handler === undefined) {
      return false;
    }
    hilog.info(0x0000, 'HOPA', `approval: ask ${action.kind}`);
    const approved: boolean = await this.handler(action, screen);
    hilog.info(0x0000, 'HOPA', `approval: answer ${approved}`);
    return approved;
  }
}

/**
 * Prefers the accessibility tree; falls back to the text of the built-in
 * browser page. That keeps web tasks and the payment gate working without the
 * ACL, while never pretending there is a screen when there is none.
 */
class CompositeScreenSource implements ScreenSource {
  private browser: BrowserController;
  private remote: RemoteBridge;

  constructor(browser: BrowserController, remote: RemoteBridge) {
    this.browser = browser;
    this.remote = remote;
  }

  async capture(): Promise<Screen> {
    if (this.remote.isConfigured()) {
      hilog.info(0x0000, 'HOPA', 'capture: bridge observe start');
      const screen: Screen = await new RemoteScreenSource(this.remote).capture();
      hilog.info(0x0000, 'HOPA', `capture: bridge observe done text=${screen.text.length} nodes=${screen.nodes.length}`);
      if (screen.text.length > 0 || screen.nodes.length > 0) {
        return screen;
      }
      // Fall through to the local paths if the PC bridge is unreachable.
    }
    if (A11yBridge.get().isAvailable()) {
      hilog.info(0x0000, 'HOPA', 'capture: a11y start');
      // A declared-but-disabled service can leave capture pending forever.
      const local: Promise<Screen> = A11yBridge.get().capture();
      const guard: Promise<Screen> = new Promise<Screen>((resolve: (value: Screen) => void) => {
        setTimeout(() => {
          resolve(new Screen(''));
        }, 4000);
      });
      return Promise.race([local, guard]);
    }
    return new Screen(await this.browser.pageText());
  }
}

/** The JSON written by the export action. The API key is never part of it. */
class ExportPayload {
  exportedAt: string = '';
  memory: MemoryItem[] = [];
  skills: Skill[] = [];
  runs: RunRecord[] = [];
}

/** Process-wide composition root: policy + gate + capabilities + tool registry. */
export class AgentService {
  private static instance: AgentService | undefined = undefined;

  readonly executor: ActionExecutor;
  readonly approvals: UiApprovalGateway;
  readonly policy: ApprovalPolicy;
  readonly runs: RunStore;
  readonly tools: ToolRegistry;
  readonly memory: MemoryStore = new MemoryStore();
  readonly skills: SkillStore = new SkillStore();
  schedules: ScheduleBook = new ScheduleBook();
  readonly batch: BatchRunner = new BatchRunner();
  readonly web: WebCapability;
  readonly browser: BrowserController;
  readonly remote: RemoteBridge = new RemoteBridge();
  readonly background: BackgroundKeeper = new BackgroundKeeper();
  readonly sandbox: SandboxCapability;
  readonly a11y: A11yCapability;
  readonly ui: UiCapability;
  readonly system: SystemCapability;

  private model: ModelClient | undefined = undefined;
  private loop: AgentLoop | undefined = undefined;
  private modelLabel: string = '';
  private networkEnabled: boolean = false;
  private autonomous: boolean = false;
  private lastTokens: number = 0;
  private lastDurationMs: number = 0;
  private lastGoal: string = '';
  private lastTranscript: string = '';
  private lastSuccess: boolean = false;
  private matchedSkillId: string = '';
  private static readonly STORE: string = 'hopa_settings';
  private static readonly RUNS_KEY: string = 'runs_v1';
  private static readonly SCHEDULES_KEY: string = 'schedules_v1';
  private static readonly SCHEDULE_TICK_MS: number = 30000;

  private abilityContext: common.UIAbilityContext | undefined = undefined;
  private scheduleTimer: number = -1;
  private activeRuns: number = 0;

  private constructor() {
    this.runs = new RunStore();
    this.approvals = new UiApprovalGateway();
    this.policy = new ApprovalPolicy();
    this.executor = new ActionExecutor(this.policy, this.approvals, this.runs);

    this.web = new WebCapability();
    this.browser = new BrowserController();
    this.web.setController(this.browser);
    this.sandbox = new SandboxCapability();
    this.a11y = new A11yCapability();
    this.ui = new UiCapability();
    this.system = new SystemCapability();

    this.executor.registerCapability(this.web);
    this.executor.registerCapability(this.sandbox);
    this.executor.registerCapability(this.a11y);
    this.executor.registerCapability(this.ui);
    this.executor.registerCapability(this.system);
    this.executor.registerCapability(new RemoteUiCapability(this.remote));

    this.tools = new ToolRegistry();
    this.tools.register(new ToolDescriptor('web.navigate', 'Navigate the web view', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('web.read', 'Read the current page', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.tap', 'Tap a screen element', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.type', 'Type into a screen element', RiskLevel.Sensitive));
    this.tools.register(new ToolDescriptor('ui.swipe', 'Scroll the current screen', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.longPress', 'Long-press a screen element', RiskLevel.Sensitive));
    this.tools.register(new ToolDescriptor('sandbox.run', 'Run an offline script', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('system.openLink', 'Open an https link', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.sendMessage', 'Send a message', RiskLevel.Sensitive));
    this.tools.register(new ToolDescriptor('payment.confirm', 'Confirm a payment', RiskLevel.Payment));
  }

  static get(): AgentService {
    if (AgentService.instance === undefined) {
      AgentService.instance = new AgentService();
    }
    return AgentService.instance;
  }

  /**
   * Creates the on-device loop. The key stays in memory only: it is never
   * written to disk and never logged.
   */
  configureModel(
    provider: string,
    endpoint: string,
    apiKey: string,
    modelName: string,
    maxSteps: number = 6
  ): void {
    if (provider === 'anthropic') {
      this.model = new AnthropicClient(endpoint, apiKey, modelName);
    } else if (provider === 'gemini') {
      this.model = new GeminiClient(endpoint, apiKey, modelName);
    } else {
      this.model = new OpenAiCompatibleClient(endpoint, apiKey, modelName);
    }
    this.loop = new AgentLoop(
      this.executor,
      new LoggedModelClient(this.model),
      maxSteps,
      new CompositeScreenSource(this.browser, this.remote)
    );
    this.loop.setMemory(this.memory.toPrompt());
    this.modelLabel = modelName;
  }

  getModelLabel(): string {
    return this.modelLabel;
  }

  hasModel(): boolean {
    return this.loop !== undefined;
  }

  isA11yAvailable(): boolean {
    return this.a11y.isAvailable();
  }

  /** Gates agent-driven web navigation. Manual browsing in the Web tab is not gated. */
  setNetworkEnabled(enabled: boolean): void {
    this.networkEnabled = enabled;
    this.web.setNetworkAllowed(enabled);
  }

  isNetworkEnabled(): boolean {
    return this.networkEnabled;
  }

  /** Wires the entry module's app launcher into the ui capability. */
  setUiLauncher(launcher: UiLauncher): void {
    this.ui.setLauncher(launcher);
  }

  /** Points the remote capability at a running `pc-agent bridge`. */
  configureRemote(url: string, token: string): void {
    this.remote.configure(url, token);
    A11yBridge.get().setRemotePreferred(this.remote.isConfigured());
  }

  private appList(): string {
    const lines: string[] = [];
    for (const app of APP_CATALOG) {
      if (app.confirmed && app.bundle.length > 0) {
        lines.push(`${app.display}: ${app.bundle}`);
      }
    }
    return lines.join('\n');
  }

  /** Enables the continuous task that keeps a run alive while backgrounded. */
  setAbilityContext(context: common.UIAbilityContext): void {
    this.background.setContext(context);
    this.abilityContext = context;
  }

  async loadSchedules(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, AgentService.STORE);
      const raw = await store.get(AgentService.SCHEDULES_KEY, '');
      this.schedules = ScheduleBook.fromJson(`${raw}`);
    } catch (error) {
      this.schedules = new ScheduleBook();
    }
  }

  async saveSchedules(): Promise<void> {
    if (this.abilityContext === undefined) {
      return;
    }
    try {
      const store = await preferences.getPreferences(this.abilityContext, AgentService.STORE);
      await store.put(AgentService.SCHEDULES_KEY, this.schedules.toJson());
      await store.flush();
    } catch (error) {
      // Losing a schedule edit is not worth failing the UI over.
    }
  }

  /** Adds a goal to the in-app schedule and persists it. */
  async addSchedule(goal: string, intervalMs: number, delayMs: number): Promise<boolean> {
    const task: ScheduledTask | undefined = this.schedules.add(goal, intervalMs, Date.now(), delayMs);
    if (task === undefined) {
      return false;
    }
    await this.saveSchedules();
    return true;
  }

  async removeSchedule(id: string): Promise<void> {
    this.schedules.remove(id);
    await this.saveSchedules();
  }

  /**
   * Fires due goals while the process is alive.
   *
   * The HarmonyOS reminder agent rejects this emulator, so this is an in-app
   * schedule, not a system alarm. It is explicit in the UI and in the docs.
   */
  startScheduler(): void {
    if (this.scheduleTimer >= 0) {
      return;
    }
    this.scheduleTimer = setInterval(() => {
      this.tickSchedules();
    }, AgentService.SCHEDULE_TICK_MS);
  }

  stopScheduler(): void {
    if (this.scheduleTimer >= 0) {
      clearInterval(this.scheduleTimer);
      this.scheduleTimer = -1;
    }
  }

  private tickSchedules(): void {
    if (this.activeRuns > 0) {
      return;
    }
    const task: ScheduledTask | undefined = this.schedules.nextDue(Date.now());
    if (task === undefined) {
      return;
    }
    this.schedules.markRan(task.id, Date.now());
    this.saveSchedules().catch(() => {
      // The run matters more than the timestamp write.
    });
    this.run(task.goal).catch(() => {
      // run() already turns failures into a transcript.
    });
  }

  isBusy(): boolean {
    return this.activeRuns > 0;
  }

  isRemoteConfigured(): boolean {
    return this.remote.isConfigured();
  }

  async testRemote(): Promise<boolean> {
    return this.remote.health();
  }

  remoteFailure(): string {
    return this.remote.lastFailure();
  }

  /** Autonomous mode skips non-payment approvals. Payment is still fail-closed. */
  setAutonomous(enabled: boolean): void {
    this.autonomous = enabled;
    this.policy.setAutonomous(enabled);
  }

  isAutonomous(): boolean {
    return this.autonomous;
  }

  /** Stops the loop before the next model call or after the current action. */
  cancel(): void {
    this.batch.cancel();
    if (this.loop !== undefined) {
      this.loop.cancel();
    }
  }

  /** Runs each goal in order; cancellation stops between goals. */
  async runBatch(goals: string[]): Promise<BatchItemResult[]> {
    return this.batch.run(goals, async (goal: string): Promise<string> => {
      return this.run(goal);
    });
  }

  getLastTokens(): number {
    return this.lastTokens;
  }

  getLastDurationMs(): number {
    return this.lastDurationMs;
  }

  canDraftSkill(): boolean {
    return this.lastSuccess && this.lastGoal.length > 0 && this.lastTranscript.length > 0;
  }

  canContinue(): boolean {
    return this.lastGoal.length > 0;
  }

  /** Re-runs the last goal with the previous transcript as context. */
  async continueLast(): Promise<string> {
    if (!this.canContinue()) {
      return 'There is no previous task to continue.';
    }
    const goal: string = this.lastGoal;
    const transcript: string = this.lastTranscript;
    const output: string = await this.run(
      `${goal}\n\nPrevious attempt:\n${transcript}\nContinue from where it stopped.`
    );
    this.lastGoal = goal;
    this.lastTranscript = `${transcript}\n${output}`;
    return output;
  }

  /** Saves the last successful run as a skill the user can edit or delete. */
  saveLastRunAsSkill(): Skill | undefined {
    const draft: SkillDraft | undefined = SkillDrafter.draft(this.lastGoal, this.lastTranscript);
    if (draft === undefined) {
      return undefined;
    }
    return this.skills.add(draft.name, draft.trigger, draft.guidance);
  }

  /** Restores the last run records shown in the Tasks tab. */
  async loadRuns(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, AgentService.STORE);
    const raw = await store.get(AgentService.RUNS_KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as RunRecord[];
      this.runs.replace(parsed);
    } catch (error) {
      // Unreadable history: keep the empty store.
    }
  }

  /** Persists the most recent records; the history is capped. */
  async saveRuns(context: Context): Promise<void> {
    const all: RunRecord[] = this.runs.all();
    const recent: RunRecord[] = all.length > 100 ? all.slice(all.length - 100) : all;
    const store = await preferences.getPreferences(context, AgentService.STORE);
    await store.put(AgentService.RUNS_KEY, JSON.stringify(recent));
    await store.flush();
  }

  /**
   * Writes memory, skills and run records to one JSON file in the app sandbox.
   * The API key is never included. The path is returned so the user can find it.
   */
  async exportData(context: Context): Promise<string> {
    const payload = new ExportPayload();
    payload.exportedAt = new Date().toISOString();
    payload.memory = this.memory.all();
    payload.skills = this.skills.all();
    payload.runs = this.runs.all();
    const path: string = `${context.filesDir}/hopa-export.json`;
    const file = fileIo.openSync(
      path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, JSON.stringify(payload, null, 2));
    } finally {
      fileIo.closeSync(file);
    }
    return path;
  }

  /**
   * Runs one goal through the loop and returns a readable transcript. It never
   * throws to the UI: failures become lines the user can read.
   */
  async run(goal: string): Promise<string> {
    this.activeRuns += 1;
    try {
      return await this.runInner(goal);
    } finally {
      this.activeRuns -= 1;
    }
  }

  private async runInner(goal: string): Promise<string> {
    if (this.loop === undefined) {
      return 'No model configured. Open Settings, enter an endpoint, a model and a key, then press Save.';
    }
    if (!this.a11y.isAvailable() && !this.browser.isReady() && !this.remote.isConfigured()) {
      // Chat still works without a screen; actions will fail closed in the executor.
      this.loop.setSurfaceAvailable(false);
    } else {
      this.loop.setSurfaceAvailable(true);
    }

    let outcomes: ActionOutcome[] = [];
    const startedAt: number = Date.now();
    this.lastGoal = goal;
    this.lastSuccess = false;
    this.lastTranscript = '';
    const matchedSkill: Skill | undefined = this.skills.match(goal);
    this.matchedSkillId = matchedSkill === undefined ? '' : matchedSkill.id;
    this.loop.setMemory(this.memory.toPrompt());
    this.loop.setSkill(this.skills.toPrompt(goal));
    this.loop.setAppCatalog(this.appList());
    this.loop.resetCancel();
    hilog.info(0x0000, 'HOPA', `run: start goal=${goal.length} chars`);
    if (this.remote.isConfigured()) {
      await this.background.begin();
    }
    try {
      outcomes = await this.loop.run(goal);
    } catch (error) {
      await this.background.end();
      return `Loop error: ${error}`;
    }
    await this.background.end();
    hilog.info(0x0000, 'HOPA', `run: done outcomes=${outcomes.length} tokens=${this.loop.getTokens()}`);
    this.lastTokens = this.loop.getTokens();
    this.lastDurationMs = Date.now() - startedAt;

    if (this.loop.wasCancelled() && outcomes.length === 0) {
      return 'Stopped before any action.';
    }

    if (outcomes.length === 0) {
      const answer: string = this.loop.getAnswer();
      if (answer.length > 0) {
        this.lastTranscript = answer;
        this.lastSuccess = !this.loop.wasCancelled();
        return answer;
      }
      return 'The model proposed no executable action.';
    }

    const lines: string[] = [];
    for (const outcome of outcomes) {
      const state: string = outcome.executed ? (outcome.observation.success ? 'ok' : 'failed') : 'denied';
      const detail: string =
        outcome.observation.summary.length > 0 ? outcome.observation.summary : outcome.observation.detail;
      lines.push(`${outcome.action.kind} -> ${state}: ${detail}`);
    }
    const transcript: string = lines.join('\n');
    this.lastTranscript = transcript;
    this.lastSuccess = !this.loop.wasCancelled() && outcomes.every(
      (outcome: ActionOutcome) => outcome.executed && outcome.observation.success
    );
    if (this.matchedSkillId.length > 0) {
      this.skills.recordOutcome(this.matchedSkillId, this.lastSuccess);
    }
    return transcript;
  }
}
