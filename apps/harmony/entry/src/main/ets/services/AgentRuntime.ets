import {
  ActionExecutor,
  ActionOutcome,
  AgentLoop,
  AppRouter,
  BatchItemResult,
  BatchRunner,
  ModelClient,
  RouteMatch,
  RunNarrator,
  Skill
} from '@hopa/core';
import { AccessibilityCapability } from '@hopa/capability-accessibility';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BrowserController } from './BrowserController';
import { BridgeClient } from './BridgeClient';
import { BackgroundKeeper } from './BackgroundKeeper';
import { CompositeScreenSource } from './CompositeScreenSource';
import { LoggingModelClient } from './LoggingModelClient';
import { ModelFactory } from './ModelFactory';
import { AppCatalogPrompt } from './AppCatalogPrompt';
import { AppRouteTargets } from './AppRouteTargets';
import { PageLinkService } from './PageLinkService';
import { MemoryStore } from './MemoryStore';
import { SkillStore } from './SkillStore';

/**
 * The agent runtime: the loop, the model, the last-run facts and the batch.
 * It owns no UI and no persistence; the composition root wires it once.
 */
export class AgentRuntime {
  private executor: ActionExecutor;
  private memory: MemoryStore;
  private skills: SkillStore;
  private browser: BrowserController;
  private bridge: BridgeClient;
  private accessibility: AccessibilityCapability;
  private background: BackgroundKeeper;
  private pageLinks: PageLinkService;

  private batch: BatchRunner = new BatchRunner();
  private model: ModelClient | undefined = undefined;
  private loop: AgentLoop | undefined = undefined;
  private modelLabel: string = '';
  private activeKey: string = '';
  private lastTokens: number = 0;
  private lastDurationMs: number = 0;
  private lastGoal: string = '';
  private lastTranscript: string = '';
  private lastSuccess: boolean = false;
  private lastActionCount: number = 0;
  private lastStepLabels: string[] = [];
  private matchedSkillId: string = '';
  private activeRuns: number = 0;
  private appNames: Map<string, string> = new Map<string, string>();

  constructor(
    executor: ActionExecutor,
    memory: MemoryStore,
    skills: SkillStore,
    browser: BrowserController,
    bridge: BridgeClient,
    accessibility: AccessibilityCapability,
    background: BackgroundKeeper,
    pageLinks: PageLinkService
  ) {
    this.executor = executor;
    this.memory = memory;
    this.skills = skills;
    this.browser = browser;
    this.bridge = bridge;
    this.accessibility = accessibility;
    this.background = background;
    this.pageLinks = pageLinks;
    this.appNames = AppRouteTargets.displayNames();
  }

  configureModel(
    provider: string,
    endpoint: string,
    apiKey: string,
    modelName: string,
    maxSteps: number = 14
  ): void {
    this.model = ModelFactory.create(provider, endpoint, apiKey, modelName);
    this.activeKey = apiKey;
    this.loop = new AgentLoop(
      this.executor,
      new LoggingModelClient(this.model),
      maxSteps,
      new CompositeScreenSource(this.browser, this.bridge)
    );
    this.loop.setMemory(this.memory.toPrompt());
    this.modelLabel = modelName;
  }

  getModelLabel(): string {
    return this.modelLabel;
  }

  hasModelKey(): boolean {
    return this.activeKey.length > 0;
  }

  /** True when the last run completed without a failed or denied action. */
  lastRunSucceeded(): boolean {
    return this.lastSuccess;
  }

  /** Human labels for the steps of the last run, newest surface first. */
  lastSteps(): string[] {
    return this.lastStepLabels;
  }

  /** True when the last run actually changed something on the phone. */
  lastRunHadActions(): boolean {
    return this.lastActionCount > 0;
  }

  /** Changes provider/endpoint/model but keeps the key already loaded. */
  reconfigureModel(
    provider: string,
    endpoint: string,
    modelName: string,
    maxSteps: number = 14
  ): void {
    this.configureModel(provider, endpoint, this.activeKey, modelName, maxSteps);
  }

  /** Restores the last-run numbers after a restart, so Usage is not all zeroes. */
  restoreLastUsage(tokens: number, durationMs: number): void {
    this.lastTokens = tokens;
    this.lastDurationMs = durationMs;
  }

  hasModel(): boolean {
    return this.loop !== undefined;
  }

  isBusy(): boolean {
    return this.activeRuns > 0;
  }

  cancel(): void {
    this.batch.cancel();
    if (this.loop !== undefined) {
      this.loop.cancel();
    }
  }

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

  saveLastRunAsSkill(): Skill | undefined {
    return this.skills.draftFrom(this.lastGoal, this.lastTranscript);
  }

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
    if (!this.accessibility.isAvailable() && !this.browser.isReady() && !this.bridge.isConfigured()) {
      this.loop.setSurfaceAvailable(false);
    } else {
      this.loop.setSurfaceAvailable(true);
    }

    let outcomes: ActionOutcome[] = [];
    const startedAt: number = Date.now();
    this.lastGoal = goal;
    this.lastSuccess = false;
    this.lastActionCount = 0;
    this.lastStepLabels = [];
    this.lastTranscript = '';
    this.pageLinks.clear();
    const matchedSkill: Skill | undefined = this.skills.match(goal);
    this.matchedSkillId = matchedSkill === undefined ? '' : matchedSkill.id;
    this.loop.setMemory(this.memory.toPrompt());
    this.loop.setSkill(this.skills.toPrompt(goal));
    this.loop.setAppCatalog(AppCatalogPrompt.text());
    const match: RouteMatch = AppRouter.route(goal, AppRouteTargets.all());
    this.loop.setRoute(AppRouter.hint(match));
    hilog.info(
      0x0000,
      'HOPA',
      `route: ${match.target === undefined ? 'none' : match.target.display} score=${match.score}`
    );
    this.loop.resetCancel();
    hilog.info(0x0000, 'HOPA', `run: start goal=${goal.length} chars`);
    if (this.bridge.isConfigured()) {
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
    for (const outcome of outcomes) {
      const stepApp: string = outcome.action.app.length > 0 ? outcome.action.app : outcome.action.target;
      const stepKind: string = outcome.action.kind;
      let stepName: string = stepKind.replace('ui.', '');
      const stepLabel: string = this.appNames.get(stepApp) ?? stepApp;
      if (stepKind === 'ui.launch') { stepName = `Opened ${stepLabel}`; }
      else if (stepKind === 'ui.tap' || stepKind === 'ui.doubleTap' || stepKind === 'ui.longPress') { stepName = 'Tapped'; }
      else if (stepKind === 'ui.type') { stepName = 'Typed'; }
      else if (stepKind === 'ui.back') { stepName = 'Back'; }
      else if (stepKind === 'ui.home') { stepName = 'Home'; }
      else if (stepKind === 'ui.swipe' || stepKind === 'ui.scroll') { stepName = 'Scrolled'; }
      const stepOk: boolean = outcome.executed && outcome.observation.success;
      this.lastStepLabels.push(`${stepOk ? '\u2713' : '\u2715'} ${stepName}`);
    }
    for (const outcome of outcomes) {
      const target: string = outcome.action.app.length > 0
        ? outcome.action.app
        : outcome.action.target;
      const state: string = outcome.executed
        ? (outcome.observation.success ? 'ok' : 'failed')
        : 'denied';
      hilog.info(0x0000, 'HOPA', `action: ${outcome.action.kind} ${target} -> ${state}`);
    }
    this.lastTokens = this.loop.getTokens();
    this.lastDurationMs = Date.now() - startedAt;
    this.lastActionCount = outcomes.length;

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
    this.pageLinks.capture(outcomes, this.browser);
    this.lastSuccess = !this.loop.wasCancelled() && outcomes.every(
      (outcome: ActionOutcome) => outcome.executed && outcome.observation.success
    );
    if (this.matchedSkillId.length > 0) {
      this.skills.recordOutcome(this.matchedSkillId, this.lastSuccess);
    }
    const answer: string = this.loop.getAnswer();
    if (answer.length > 0) {
      return answer;
    }
    return RunNarrator.summarize(outcomes, this.appNames);
  }
}
