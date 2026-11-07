import {
  ActionExecutor,
  ActionOutcome,
  AgentLoop,
  ApprovalPolicy,
  BatchItemResult,
  BatchRunner,
  ModelClient,
  RiskLevel,
  RunRecord,
  RunStore,
  ScheduleBook,
  ScheduledTask,
  Skill,
  SkillDraft,
  SkillDrafter,
  ToolDescriptor,
  ToolRegistry
} from '@hopa/core';
import { WebCapability } from '@hopa/capability-web';
import { SandboxCapability } from '@hopa/capability-sandbox';
import { A11yBridge, A11yCapability, UiCapability, UiLauncher } from '@hopa/capability-a11y';
import { SystemCapability } from '@hopa/capability-system';
import { Context, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BrowserController } from './BrowserController';
import { BackgroundKeeper } from './BackgroundKeeper';
import { RemoteBridge } from './RemoteBridge';
import { RemoteUiCapability } from './RemoteUiCapability';
import { MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';
import { UiApprovalGateway } from './ApprovalPromptGateway';
import { CompositeScreenSource } from './CompositeScreenSource';
import { LoggingModelClient } from './LoggingModelClient';
import { ModelFactory } from './ModelFactory';
import { AppCatalogPrompt } from './AppCatalogPrompt';
import { ScheduleService } from './ScheduleService';
import { RunArchive } from './RunArchive';
import { ExportService } from './ExportService';

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
  readonly scheduleService: ScheduleService = new ScheduleService();
  readonly batch: BatchRunner = new BatchRunner();
  readonly web: WebCapability;
  readonly browser: BrowserController;
  readonly remote: RemoteBridge = new RemoteBridge();
  readonly background: BackgroundKeeper = new BackgroundKeeper();
  readonly sandbox: SandboxCapability;
  readonly a11y: A11yCapability;
  readonly ui: UiCapability;
  readonly system: SystemCapability;
  readonly runArchive: RunArchive;
  readonly exportService: ExportService;

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

    this.runArchive = new RunArchive(this.runs);
    this.exportService = new ExportService(this.memory, this.skills, this.runs);
    this.scheduleService.bindRunner(
      (goal: string): Promise<string> => this.run(goal),
      (): boolean => this.isBusy()
    );
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
    this.model = ModelFactory.create(provider, endpoint, apiKey, modelName);
    this.loop = new AgentLoop(
      this.executor,
      new LoggingModelClient(this.model),
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

  isRemoteConfigured(): boolean {
    return this.remote.isConfigured();
  }

  async testRemote(): Promise<boolean> {
    return this.remote.health();
  }

  remoteFailure(): string {
    return this.remote.lastFailure();
  }

  /** Enables the continuous task that keeps a run alive while backgrounded. */
  setAbilityContext(context: common.UIAbilityContext): void {
    this.background.setContext(context);
    this.scheduleService.setContext(context);
  }

  /** The schedule view for the UI. */
  get schedules(): ScheduleBook {
    return this.scheduleService.book;
  }

  loadSchedules(context: Context): Promise<void> {
    return this.scheduleService.load(context);
  }

  saveSchedules(): Promise<void> {
    return this.scheduleService.save();
  }

  addSchedule(goal: string, intervalMs: number, delayMs: number): Promise<boolean> {
    return this.scheduleService.add(goal, intervalMs, delayMs);
  }

  removeSchedule(id: string): Promise<void> {
    return this.scheduleService.remove(id);
  }

  startScheduler(): void {
    this.scheduleService.start();
  }

  stopScheduler(): void {
    this.scheduleService.stop();
  }

  isBusy(): boolean {
    return this.activeRuns > 0;
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

  loadRuns(context: Context): Promise<void> {
    return this.runArchive.load(context);
  }

  saveRuns(context: Context): Promise<void> {
    return this.runArchive.save(context);
  }

  exportData(context: Context): Promise<string> {
    return this.exportService.exportData(context);
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
    this.loop.setAppCatalog(AppCatalogPrompt.text());
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
