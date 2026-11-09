import { Action, ActionOutcome, Observation } from '../Types';
import { ActionExecutor } from '../gate/ActionExecutor';
import { ModelClient, ModelMessage, ModelRequest, ModelResponse } from '../model/ModelClient';
import { Screen, ScreenSource } from '../domain/Screen';
import { ContextBudget } from './ContextBudget';
import { ActionParser } from './ActionParser';
import { PromptBuilder } from './PromptBuilder';

/**
 * A minimal agent loop: capture the screen, ask the model for one action,
 * execute it through the gate, capture again, and feed the observation back.
 * Production code will add planning, memory and richer verification; the gate
 * must not change.
 */
export class AgentLoop {
  private executor: ActionExecutor;
  private model: ModelClient;
  private maxSteps: number;
  private source?: ScreenSource;
  private memory: string = '';
  private skill: string = '';
  private apps: string = '';
  private route: string = '';
  private budget: ContextBudget = new ContextBudget();
  private tokensUsed: number = 0;
  private cancelled: boolean = false;
  private answer: string = '';
  private surfaceAvailable: boolean = true;

  constructor(
    executor: ActionExecutor,
    model: ModelClient,
    maxSteps: number = 10,
    source?: ScreenSource
  ) {
    this.executor = executor;
    this.model = model;
    this.maxSteps = maxSteps;
    this.source = source;
  }

  setMemory(memory: string): void {
    this.memory = memory;
  }

  setSkill(skill: string): void {
    this.skill = skill;
  }

  /** The known bundle/name pairs, so the model never guesses an Android name. */
  setAppCatalog(apps: string): void {
    this.apps = apps;
  }

  /** The deterministic router's suggestion for this goal, or ''. */
  setRoute(route: string): void {
    this.route = route;
  }

  /** Total tokens reported by the model during the last run. */
  getTokens(): number {
    return this.tokensUsed;
  }

  /** Ask the loop to stop before the next model call or after the current action. */
  cancel(): void {
    this.cancelled = true;
  }

  resetCancel(): void {
    this.cancelled = false;
  }

  wasCancelled(): boolean {
    return this.cancelled;
  }

  /** A plain-text reply when the model answers instead of proposing an action. */
  getAnswer(): string {
    return this.answer;
  }

  setSurfaceAvailable(available: boolean): void {
    this.surfaceAvailable = available;
  }

  async run(goal: string): Promise<ActionOutcome[]> {
    const outcomes: ActionOutcome[] = [];
    const launched: string[] = [];
    this.tokensUsed = 0;
    this.cancelled = false;
    this.answer = '';
    let screen: Screen = await this.capture();
    let systemText: string = PromptBuilder.systemPrompt(
      this.memory,
      this.skill,
      this.apps,
      this.surfaceAvailable
    );
    if (this.route.length > 0) {
      systemText = `${systemText}\n\n${this.route}`;
    }
    const messages: ModelMessage[] = [
      new ModelMessage('system', systemText),
      new ModelMessage('user', `${goal}\n\nSCREEN:\n${PromptBuilder.screenText(screen)}`)
    ];

    for (let step = 0; step < this.maxSteps; step++) {
      if (this.cancelled) {
        break;
      }
      const request = new ModelRequest();
      request.messages = this.budget.trim(messages);
      const response: ModelResponse = await this.model.complete(request);
      this.tokensUsed += response.tokens;
      if (this.cancelled) {
        break;
      }
      if (response.error.length > 0) {
        throw new Error(`model request failed: ${response.error}`);
      }
      if (response.text.trim().length === 0) {
        break;
      }

      const action: Action | undefined = ActionParser.parse(response.text);
      if (action === undefined) {
        // Not an action: treat it as the final answer when it is real text.
        const text: string = response.text.trim();
        if (text.length > 0) {
          this.answer = text;
        }
        break;
      }

      const launch: string = AgentLoop.launchBundle(action);
      if (launch.length > 0 && launched.indexOf(launch) >= 0) {
        // HarmonyOS refuses a UIAbility start from the background, so a second
        // launch of the same app cannot succeed. Keep the first result and let
        // the model work with the screen it already has.
        const repeated: ActionOutcome = new ActionOutcome(
          action,
          Observation.ok(`already launched ${launch} in this run`)
        );
        repeated.executed = true;
        repeated.approved = true;
        repeated.verified = true;
        outcomes.push(repeated);
        messages.push(new ModelMessage('assistant', response.text));
        messages.push(
          new ModelMessage(
            'user',
            `Observation: ${repeated.observation.summary}\n` +
              'Do not launch the same app twice; use the ELEMENTS to act.\n' +
              `SCREEN:\n${PromptBuilder.screenText(screen)}`
          )
        );
        continue;
      }

      const outcome: ActionOutcome = await this.executor.execute(action, screen);
      outcomes.push(outcome);
      if (launch.length > 0 && outcome.executed && outcome.observation.success) {
        launched.push(launch);
      }

      messages.push(new ModelMessage('assistant', response.text));
      screen = await this.capture();
      messages.push(
        new ModelMessage(
          'user',
          `Observation: ${outcome.observation.summary} ${outcome.observation.detail}\n` +
            `SCREEN:\n${PromptBuilder.screenText(screen)}`
        )
      );

      if (!outcome.executed || !outcome.observation.success) {
        break;
      }
      if (this.cancelled) {
        break;
      }
    }

    return outcomes;
  }

  private async capture(): Promise<Screen> {
    if (this.source === undefined) {
      return new Screen();
    }
    return this.source.capture();
  }

  /** The lower-case bundle a launch action asks for, or '' for other actions. */
  private static launchBundle(action: Action): string {
    if (action.kind !== 'ui.launch') {
      return '';
    }
    const raw: string = action.app.length > 0 ? action.app : action.target;
    return raw.trim().toLowerCase();
  }

}
