import {
  ActionExecutor,
  ApprovalPolicy,
  BatchItemResult,
  RunStore,
  Skill,
  ToolRegistry
} from '@hopa/core';
import { BrowserCapability } from '@hopa/capability-browser';
import { SandboxCapability } from '@hopa/capability-sandbox';
import {
  AccessibilityBridge,
  AccessibilityCapability,
  UiActionCapability,
  UiLauncher
} from '@hopa/capability-accessibility';
import { SystemCapability } from '@hopa/capability-system';
import { Context, common } from '@kit.AbilityKit';
import { BrowserController } from './BrowserController';
import { BackgroundKeeper } from './BackgroundKeeper';
import { BridgeClient } from './BridgeClient';
import { BridgeUiCapability } from './BridgeUiCapability';
import { MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';
import { UiApprovalGateway } from './ApprovalPromptGateway';
import { ScheduleService } from './ScheduleService';
import { RunArchive } from './RunArchive';
import { ExportService } from './ExportService';
import { ConversationService } from './ConversationService';
import { PageLinkService } from './PageLinkService';
import { AgentRuntime } from './AgentRuntime';
import { ToolRegistryDefaults } from './ToolRegistryDefaults';

/** Process-wide composition root: policy + gate + capabilities + runtime. */
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
  readonly browserCapability: BrowserCapability;
  readonly browser: BrowserController;
  readonly bridge: BridgeClient = new BridgeClient();
  readonly background: BackgroundKeeper = new BackgroundKeeper();
  readonly sandbox: SandboxCapability;
  readonly accessibility: AccessibilityCapability;
  readonly ui: UiActionCapability;
  readonly system: SystemCapability;
  readonly runArchive: RunArchive;
  readonly conversations: ConversationService = new ConversationService();
  readonly pageLinks: PageLinkService = new PageLinkService();
  readonly exportService: ExportService;
  readonly runtime: AgentRuntime;

  private networkEnabled: boolean = false;
  private autonomous: boolean = false;
  private runDone: (() => void) | undefined = undefined;

  private constructor() {
    this.runs = new RunStore();
    this.approvals = new UiApprovalGateway();
    this.policy = new ApprovalPolicy();
    this.executor = new ActionExecutor(this.policy, this.approvals, this.runs);

    this.browserCapability = new BrowserCapability();
    this.browser = new BrowserController();
    this.browserCapability.setController(this.browser);
    this.sandbox = new SandboxCapability();
    this.accessibility = new AccessibilityCapability();
    this.ui = new UiActionCapability();
    this.system = new SystemCapability();

    this.executor.registerCapability(this.browserCapability);
    this.executor.registerCapability(this.sandbox);
    this.executor.registerCapability(this.accessibility);
    this.executor.registerCapability(this.ui);
    this.executor.registerCapability(this.system);
    this.executor.registerCapability(new BridgeUiCapability(this.bridge));

    this.tools = ToolRegistryDefaults.create();

    this.runArchive = new RunArchive(this.runs);
    this.exportService = new ExportService(this.memory, this.skills, this.runs);
    this.runtime = new AgentRuntime(
      this.executor,
      this.memory,
      this.skills,
      this.browser,
      this.bridge,
      this.accessibility,
      this.background,
      this.pageLinks
    );
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

  configureModel(
    provider: string,
    endpoint: string,
    apiKey: string,
    modelName: string,
    maxSteps: number = 6
  ): void {
    this.runtime.configureModel(provider, endpoint, apiKey, modelName, maxSteps);
  }

  getModelLabel(): string {
    return this.runtime.getModelLabel();
  }

  hasModel(): boolean {
    return this.runtime.hasModel();
  }

  isAccessibilityAvailable(): boolean {
    return this.accessibility.isAvailable();
  }

  /** Gates agent-driven web navigation. Manual browsing is not gated. */
  setNetworkEnabled(enabled: boolean): void {
    this.networkEnabled = enabled;
    this.browserCapability.setNetworkAllowed(enabled);
  }

  isNetworkEnabled(): boolean {
    return this.networkEnabled;
  }

  setUiLauncher(launcher: UiLauncher): void {
    this.ui.setLauncher(launcher);
  }

  /** Opens the Browser page from Chat and resolves when its WebView is ready. */
  setSiteOpener(opener: (url: string) => Promise<boolean>): void {
    this.browserCapability.setSiteOpener(opener);
  }

  /** Called after every run, so the UI can return to Chat when the answer is ready. */
  setRunDoneListener(listener: () => void): void {
    this.runDone = listener;
  }

  /** Points the bridge capability at a running `pc-agent bridge`. */
  configureBridge(url: string, token: string): void {
    this.bridge.configure(url, token);
    AccessibilityBridge.get().setBridgePreferred(this.bridge.isConfigured());
  }

  isBridgeConfigured(): boolean {
    return this.bridge.isConfigured();
  }

  async testBridge(): Promise<boolean> {
    return this.bridge.health();
  }

  bridgeFailure(): string {
    return this.bridge.lastFailure();
  }

  setAbilityContext(context: common.UIAbilityContext): void {
    this.background.setContext(context);
    this.scheduleService.setContext(context);
  }

  isBusy(): boolean {
    return this.runtime.isBusy();
  }

  setAutonomous(enabled: boolean): void {
    this.autonomous = enabled;
    this.policy.setAutonomous(enabled);
  }

  isAutonomous(): boolean {
    return this.autonomous;
  }

  cancel(): void {
    this.runtime.cancel();
  }

  runBatch(goals: string[]): Promise<BatchItemResult[]> {
    return this.runtime.runBatch(goals);
  }

  getLastTokens(): number {
    return this.runtime.getLastTokens();
  }

  getLastDurationMs(): number {
    return this.runtime.getLastDurationMs();
  }

  canDraftSkill(): boolean {
    return this.runtime.canDraftSkill();
  }

  canContinue(): boolean {
    return this.runtime.canContinue();
  }

  continueLast(): Promise<string> {
    return this.runtime.continueLast();
  }

  saveLastRunAsSkill(): Skill | undefined {
    return this.runtime.saveLastRunAsSkill();
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

  async run(goal: string): Promise<string> {
    try {
      return await this.runtime.run(goal);
    } finally {
      if (this.runDone !== undefined) {
        this.runDone();
      }
    }
  }
}
