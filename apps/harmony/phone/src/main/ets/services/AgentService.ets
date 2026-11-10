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
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { BrowserController } from './BrowserController';
import { BackgroundKeeper } from './BackgroundKeeper';
import { BridgeClient } from './BridgeClient';
import { BridgeSessionStore } from './BridgeSessionStore';
import { RemoteUiCapability } from './RemoteUiCapability';
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
import { SettingsStore, StoredSettings } from './SettingsStore';

/** Process-wide composition root: policy + gate + capabilities + runtime. */
class SessionTurnSnapshot {
  role: string = '';
  text: string = '';
}

class SessionSnapshot {
  id: string = '';
  title: string = '';
  updated: number = 0;
  turns: SessionTurnSnapshot[] = [];
}

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
  private context: Context | undefined = undefined;

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
    this.executor.registerCapability(new RemoteUiCapability(this.bridge));

    this.tools = ToolRegistryDefaults.create();
    this.bridge.setSessionSink(new BridgeSessionStore());
    this.conversations.setChangeListener(() => {
      this.scheduleSessionRelay();
    });

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
    maxSteps: number = 14
  ): void {
    this.runtime.configureModel(provider, endpoint, apiKey, modelName, maxSteps);
  }

  getModelLabel(): string {
    return this.runtime.getModelLabel();
  }

  hasModelKey(): boolean {
    return this.runtime.hasModelKey();
  }

  lastRunSucceeded(): boolean {
    return this.runtime.lastRunSucceeded();
  }

  lastRunHadActions(): boolean {
    return this.runtime.lastRunHadActions();
  }

  /** Keeps the loaded key while changing provider, endpoint or model name. */
  reconfigureModel(provider: string, endpoint: string, modelName: string): void {
    this.runtime.reconfigureModel(provider, endpoint, modelName);
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

  private relayTimer: number = -1;

  /** A quiet 2.5 s debounce: one snapshot per burst of messages. */
  scheduleSessionRelay(): void {
    if (!this.bridge.isConfigured()) {
      return;
    }
    if (this.relayTimer >= 0) {
      clearTimeout(this.relayTimer);
    }
    this.relayTimer = setTimeout(() => {
      this.relayTimer = -1;
      this.relaySessions();
    }, 2500);
  }

  private async relaySessions(): Promise<void> {
    const payload: string = JSON.stringify({ sessions: this.sessionsSnapshot() });
    await this.bridge.pushSessions(payload);
  }

  /** The same shape the laptop's sidebar understands. */
  private sessionsSnapshot(): SessionSnapshot[] {
    const snapshots: SessionSnapshot[] = [];
    for (const session of this.conversations.all()) {
      const snapshot = new SessionSnapshot();
      snapshot.id = session.id;
      snapshot.title = session.title;
      snapshot.updated = session.updatedAt;
      for (const entry of session.entries) {
        const turn = new SessionTurnSnapshot();
        turn.role = entry.role;
        turn.text = entry.text;
        snapshot.turns.push(turn);
      }
      snapshots.push(snapshot);
    }
    return snapshots;
  }

  /** Points the bridge capability at a running `pc-agent bridge`. */
  configureBridge(url: string, token: string): void {
    this.bridge.configure(url, token);
    AccessibilityBridge.get().setBridgePreferred(this.bridge.isConfigured());
  }

  /** A paired session: access token plus the token that renews it. */
  configureBridgeSession(url: string, token: string, refresh: string): void {
    this.bridge.configureSession(url, token, refresh);
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
    this.context = context;
    this.background.setContext(context);
    this.scheduleService.setContext(context);
  }

  /** Restores last-run numbers saved at the end of the previous session. */
  restoreLastUsage(tokens: number, durationMs: number): void {
    this.runtime.restoreLastUsage(tokens, durationMs);
  }

  private persistUsage(): void {
    if (this.context === undefined) {
      return;
    }
    const context: Context = this.context;
    this.saveRuns(context).catch(() => {
      // Run history is best effort.
    });
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.lastTokens = this.runtime.getLastTokens();
      stored.lastDurationMs = this.runtime.getLastDurationMs();
      return SettingsStore.save(context, stored);
    }).catch(() => {
      // Usage persistence is best effort.
    });
  }

  isBusy(): boolean {
    return this.runtime.isBusy();
  }

  /** Downscales and saves the frames captured during the last run. */
  async persistStepShots(context: Context): Promise<void> {
    const shots: string[] = this.runtime.stepShots();
    const ids: string[] = this.runtime.stepShotIds();
    if (shots.length === 0 || ids.length === 0) {
      return;
    }
    const dir: string = `${context.filesDir}/steps`;
    try {
      fs.mkdirSync(dir);
    } catch (error) {
      // The directory already exists.
    }
    let attached: number = 0;
    for (let index = 0; index < shots.length && index < ids.length; index++) {
      const marker: number = shots[index].indexOf('base64,');
      if (marker < 0) {
        continue;
      }
      try {
        const helper: util.Base64Helper = new util.Base64Helper();
        const bytes: Uint8Array = helper.decodeSync(shots[index].substring(marker + 7));
        const buffer: ArrayBuffer = bytes.buffer.slice(
          bytes.byteOffset,
          bytes.byteOffset + bytes.byteLength
        );
        let jpeg: ArrayBuffer = buffer;
        try {
          const source = image.createImageSource(buffer);
          const pixel = await source.createPixelMap();
          await pixel.scale(0.35, 0.35);
          const packer: image.ImagePacker = image.createImagePacker();
          jpeg = await packer.packing(pixel, { format: 'image/jpeg', quality: 55 });
          pixel.release();
          source.release();
        } catch (error) {
          // Fall back to the original frame when scaling is unavailable.
        }
        const path: string = `${dir}/${ids[index]}.jpg`;
        const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
        try {
          fs.writeSync(file.fd, jpeg);
        } finally {
          fs.closeSync(file);
        }
        if (this.runs.attachShot(ids[index], path)) {
          attached += 1;
        }
      } catch (error) {
        // One frame is optional.
      }
    }
    if (attached > 0) {
      await this.saveRuns(context);
    }
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
      this.persistUsage();
      if (this.runDone !== undefined) {
        this.runDone();
      }
    }
  }
}
