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
import { BrowserController } from './BrowserController';
import { MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';

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
  readonly web: WebCapability;
  readonly browser: BrowserController;
  readonly sandbox: SandboxCapability;
  readonly a11y: A11yCapability;
  readonly ui: UiCapability;
  readonly system: SystemCapability;

  private model: ModelClient | undefined = undefined;
  private loop: AgentLoop | undefined = undefined;
  private modelLabel: string = '';

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
