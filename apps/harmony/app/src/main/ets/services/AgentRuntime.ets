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
import { AppCatalogPrompt } from './AppCatalogPrompt';
import { AppRouteTargets } from './AppRouteTargets';
import { BridgeClient } from './BridgeClient';
import { LoggingModelClient } from './LoggingModelClient';
import { MemoryStore } from './MemoryStore';
import { ModelFactory } from './ModelFactory';
import { SkillStore } from './SkillStore';
import {
  RuntimeBrowser,
  RuntimeBackground,
  RuntimeAccessibility,
  RuntimePageLinks
} from './RuntimeDeps';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScreenSource } from '@hopa/core';

/**
 * The agent runtime: the loop, the model, the last-run facts and the batch.
 * It owns no UI and no persistence; the composition root wires it once.
 */
export class AgentRuntime {
  private executor: ActionExecutor;
  private memory: MemoryStore;
  private skills: SkillStore;
  private browser: RuntimeBrowser;
  private bridge: BridgeClient;
  private accessibility: RuntimeAccessibility;
  private background: RuntimeBackground;
  private pageLinks: RuntimePageLinks;
  private screen: ScreenSource;
  /** The ability to raise when a run leaves this shell; the host knows it. */
  private homeAbility: string = '';

  setHomeAbility(ability: string): void {
    this.homeAbility = ability;
  }

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
  private lastTypedLength: number = 0;
  private lastStepShots: string[] = [];
  private lastStepShotIds: string[] = [];
  private matchedSkillId: string = '';
  private activeRuns: number = 0;
  private appNames: Map<string, string> = new Map<string, string>();

  constructor(
    executor: ActionExecutor,
    memory: MemoryStore,
    skills: SkillStore,
    browser: RuntimeBrowser,
    bridge: BridgeClient,
    accessibility: RuntimeAccessibility,
    background: RuntimeBackground,
    pageLinks: RuntimePageLinks,
    screen: ScreenSource
  ) {
    this.executor = executor;
    this.memory = memory;
    this.skills = skills;
    this.browser = browser;
    this.bridge = bridge;
    this.accessibility = accessibility;
    this.background = background;
    this.pageLinks = pageLinks;
    this.screen = screen;
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
      this.screen
    );
    this.loop.onStep = (outcome: ActionOutcome): Promise<void> => {
      return this.recordStep(outcome);
    };
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

  /**
   * Records a step and, when another app is in front, one frame of it.
   * The frame is only a thumbnail source; the service downscales and persists.
   */
  private async recordStep(outcome: ActionOutcome): Promise<void> {
    this.lastStepLabels.push(this.stepLabel(outcome));
    if (!outcome.executed || !outcome.observation.success) {
      return;
    }
    if (!this.bridge.isConfigured() || this.lastStepShots.length >= 6) {
      return;
    }
    if (!outcome.action.kind.startsWith('ui.') && !outcome.action.kind.startsWith('web.')) {
      return;
    }
    try {
      const foreground: string = await this.bridge.foregroundBundle();
      if (foreground.length === 0 || foreground === 'com.hopa.agent') {
        return;
      }
      const shot: string = await this.bridge.screenshot();
      if (shot.length > 0) {
        this.lastStepShots.push(shot);
        this.lastStepShotIds.push(outcome.recordId);
      }
    } catch (error) {
      // A frame is optional; never fail a run for it.
    }
  }

  stepShots(): string[] {
    return this.lastStepShots;
  }

  stepShotIds(): string[] {
    return this.lastStepShotIds;
  }

  /** Human labels for the steps of the last run, newest surface first. */
  private stepLabel(outcome: ActionOutcome): string {
    const stepApp: string = outcome.action.app.length > 0 ? outcome.action.app : outcome.action.target;
    const stepKind: string = outcome.action.kind;
    const ok: boolean = outcome.executed && outcome.observation.success;
    let stepName: string = stepKind.replace('ui.', '');
    const label: string = this.appNames.get(stepApp) ?? stepApp;
    if (stepKind === 'ui.launch') { stepName = `Opened ${label}`; }
    else if (stepKind === 'ui.tap' || stepKind === 'ui.doubleTap' || stepKind === 'ui.longPress') { stepName = 'Tapped'; }
    else if (stepKind === 'ui.type') {
      stepName = 'Typed';
      if (ok) {
        this.lastTypedLength = outcome.action.text.length;
      }
    }
    else if (stepKind === 'ui.back') { stepName = 'Back'; }
    else if (stepKind === 'ui.home') { stepName = 'Home'; }
    else if (stepKind === 'ui.swipe' || stepKind === 'ui.scroll') { stepName = 'Scrolled'; }
    return `${ok ? '\u2713' : '\u2715'} ${stepName}`;
  }

  /** The goal of the last run, so a new chat can offer to resume it. */
  lastGoalText(): string {
    return this.lastGoal;
  }

  lastSteps(): string[] {
    return this.lastStepLabels;
  }

  /** Characters typed by the last run, so Undo can remove them. */
  typedLength(): number {
    return this.lastTypedLength;
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

  /** True when an executed UI action moved another app in front of HOPA. */
  private leftHopa(outcomes: ActionOutcome[]): boolean {
    for (const outcome of outcomes) {
      if (outcome.executed && outcome.observation.success && outcome.action.kind.startsWith('ui.')) {
        return true;
      }
    }
    return false;
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
    this.lastStepShots = [];
    this.lastStepShotIds = [];
    this.lastTypedLength = 0;
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
      await this.background.returnToForeground();
      await this.background.end();
      return `Loop error: ${error}`;
    }
    // The loop may have left another app in front of HOPA. Bring HOPA back so
    // the answer is visible when the run finishes. The system blocks a
    // background app from starting its own UIAbility, so ask the PC bridge to
    // run `aa start` for HOPA first; the local path is the fallback.
    if (this.leftHopa(outcomes)) {
      let returned: boolean = false;
      if (this.bridge.isConfigured()) {
        returned = await this.bridge.focus('com.hopa.agent', this.homeAbility);
        hilog.info(0x0000, 'HOPA', `focus: bridge return ${returned}`);
      }
      if (!returned) {
        await this.background.returnToForeground();
      }
    }
    await this.background.end();
    hilog.info(0x0000, 'HOPA', `run: done outcomes=${outcomes.length} tokens=${this.loop.getTokens()}`);
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
