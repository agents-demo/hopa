import {
  ActionExecutor,
  ActionOutcome,
  AgentLoop,
  BatchItemResult,
  BatchRunner,
  ModelClient,
  Skill,
  SkillDraft,
  SkillDrafter
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

  private batch: BatchRunner = new BatchRunner();
  private model: ModelClient | undefined = undefined;
  private loop: AgentLoop | undefined = undefined;
  private modelLabel: string = '';
  private lastTokens: number = 0;
  private lastDurationMs: number = 0;
  private lastGoal: string = '';
  private lastTranscript: string = '';
  private lastSuccess: boolean = false;
  private matchedSkillId: string = '';
  private activeRuns: number = 0;

  constructor(
    executor: ActionExecutor,
    memory: MemoryStore,
    skills: SkillStore,
    browser: BrowserController,
    bridge: BridgeClient,
    accessibility: AccessibilityCapability,
    background: BackgroundKeeper
  ) {
    this.executor = executor;
    this.memory = memory;
    this.skills = skills;
    this.browser = browser;
    this.bridge = bridge;
    this.accessibility = accessibility;
    this.background = background;
  }

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
      new CompositeScreenSource(this.browser, this.bridge)
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
    const draft: SkillDraft | undefined = SkillDrafter.draft(this.lastGoal, this.lastTranscript);
    if (draft === undefined) {
      return undefined;
    }
    return this.skills.add(draft.name, draft.trigger, draft.guidance);
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
    this.lastTranscript = '';
    const matchedSkill: Skill | undefined = this.skills.match(goal);
    this.matchedSkillId = matchedSkill === undefined ? '' : matchedSkill.id;
    this.loop.setMemory(this.memory.toPrompt());
    this.loop.setSkill(this.skills.toPrompt(goal));
    this.loop.setAppCatalog(AppCatalogPrompt.text());
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
