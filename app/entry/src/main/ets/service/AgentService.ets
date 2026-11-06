import {
  Action,
  ActionExecutor,
  ActionOutcome,
  AgentLoop,
  AnthropicClient,
  ApprovalGateway,
  ApprovalPolicy,
  GeminiClient,
  ModelClient,
  OpenAiCompatibleClient,
  RiskLevel,
  RunRecord,
  RunStore,
  Screen,
  ScreenSource,
  ToolDescriptor,
  ToolRegistry
} from '@hopa/core';
import { WebCapability } from '@hopa/capability-web';
import { SandboxCapability } from '@hopa/capability-sandbox';
import { A11yBridge, A11yCapability, UiCapability } from '@hopa/capability-a11y';
import { SystemCapability } from '@hopa/capability-system';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { BrowserController } from './BrowserController';
import { MemoryItem, MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';
import { ReminderStore } from './ReminderStore';
import { Skill } from '@hopa/core';

/** Called when an action needs the user's decision. Must be fail-closed. */
export type ApprovalPrompt = (action: Action, screen: Screen | undefined) => Promise<boolean>;

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
    return this.handler(action, screen);
  }
}

/**
 * Prefers the accessibility tree; falls back to the text of the built-in
 * browser page. That keeps web tasks and the payment gate working without the
 * ACL, while never pretending there is a screen when there is none.
 */
class CompositeScreenSource implements ScreenSource {
  private browser: BrowserController;

  constructor(browser: BrowserController) {
    this.browser = browser;
  }

  async capture(): Promise<Screen> {
    if (A11yBridge.get().isAvailable()) {
      return A11yBridge.get().capture();
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
  readonly reminders: ReminderStore = new ReminderStore();
  readonly web: WebCapability;
  readonly browser: BrowserController;
  readonly sandbox: SandboxCapability;
  readonly a11y: A11yCapability;
  readonly ui: UiCapability;
  readonly system: SystemCapability;

  private model: ModelClient | undefined = undefined;
  private loop: AgentLoop | undefined = undefined;
  private modelLabel: string = '';
  private networkEnabled: boolean = false;
  private static readonly STORE: string = 'hopa_settings';
  private static readonly RUNS_KEY: string = 'runs_v1';

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
      this.model,
      maxSteps,
      new CompositeScreenSource(this.browser)
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
    if (this.loop === undefined) {
      return 'No model configured. Open Settings, enter an endpoint, a model and a key, then press Save.';
    }
    if (!this.a11y.isAvailable() && !this.browser.isReady()) {
      return 'HOPA has no screen to look at. Access is unavailable (the extension is not declared ' +
        'and no ACL is filed), and the built-in browser has not loaded a page yet. ' +
        'Open the Web tab and load a page, or enable accessibility. The model was not called.';
    }

    let outcomes: ActionOutcome[] = [];
    this.loop.setMemory(this.memory.toPrompt());
    this.loop.setSkill(this.skills.toPrompt(goal));
    try {
      outcomes = await this.loop.run(goal);
    } catch (error) {
      return `Loop error: ${error}`;
    }

    if (outcomes.length === 0) {
      return 'The model proposed no executable action.';
    }

    const lines: string[] = [];
    for (const outcome of outcomes) {
      const state: string = outcome.executed ? (outcome.observation.success ? 'ok' : 'failed') : 'denied';
      const detail: string =
        outcome.observation.summary.length > 0 ? outcome.observation.summary : outcome.observation.detail;
      lines.push(`${outcome.action.kind} -> ${state}: ${detail}`);
    }
    return lines.join('\n');
  }
}
