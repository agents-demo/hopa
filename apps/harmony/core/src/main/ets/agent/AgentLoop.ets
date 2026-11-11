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
  /**
   * Hosts that cannot execute in the background (a desktop shell) stop the loop
   * at a launch: the launch hands the foreground away, and everything after it
   * would run while the app is backgrounded - which the scheduler freezes.
   */
  private stopAfterLaunch: boolean = false;
  private stoppedAfterLaunch: boolean = false;

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

  setStopAfterLaunch(stop: boolean): void {
    this.stopAfterLaunch = stop;
  }

  setSurfaceAvailable(available: boolean): void {
    this.surfaceAvailable = available;
  }

  /** Called after each action so the UI can show steps as they happen. */
  onStep: (outcome: ActionOutcome) => void | Promise<void> = () => {};

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
      this.stoppedAfterLaunch = false;
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
        await this.onStep(repeated);
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
      await this.onStep(outcome);
      if (launch.length > 0 && outcome.executed && outcome.observation.success) {
        launched.push(launch);
        if (this.stopAfterLaunch) {
          // Do not observe or ask the model again: this app is already in the
          // background now, and any further work here is what gets it frozen.
          this.stoppedAfterLaunch = true;
          break;
        }
      }

      messages.push(new ModelMessage('assistant', response.text));
      if (launch.length > 0 && outcome.executed && outcome.observation.success) {
        // Let the foreground hand-over finish. Observing during the transition
        // runs a device-side layout dump while the ability is being backgrounded,
        // and the resource scheduler then suspends the shell (lifecycle timeout).
        await new Promise<void>((resolve: () => void) => {
          setTimeout(resolve, 1500);
        });
      }
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

    // A run that used every step on actions, or stopped on a failed one, used
    // to return an empty answer: the chat drew nothing and the question looked
    // ignored. Ask once more for text only, then fall back to what happened.
    if (this.answer.trim().length === 0 && !this.cancelled && !this.stoppedAfterLaunch) {
      this.answer = await this.finalAnswer(messages);
    }
    if (this.answer.trim().length === 0) {
      this.answer = AgentLoop.summarize(outcomes);
    }

    return outcomes;
  }

  private async capture(): Promise<Screen> {
    if (this.source === undefined) {
      return new Screen();
    }
    return this.source.capture();
  }

  /** One last text-only turn when the loop ran out of steps or stopped. */
  private async finalAnswer(messages: ModelMessage[]): Promise<string> {
    const request = new ModelRequest();
    request.messages = this.budget.trim(messages.concat([
      new ModelMessage(
        'user',
        'No more actions are available. Answer the user now in plain text, using ' +
        'what the observations above showed. Do not propose another action.'
      )
    ]));
    try {
      const response: ModelResponse = await this.model.complete(request);
      this.tokensUsed += response.tokens;
      const text: string = response.text.trim();
      if (text.length === 0 || ActionParser.parse(text) !== undefined) {
        return '';
      }
      return text;
    } catch (error) {
      return '';
    }
  }

  /** The truth when the model cannot speak: what the run actually did. */
  private static summarize(outcomes: ActionOutcome[]): string {
    if (outcomes.length === 0) {
      return 'I could not get an answer for that. Try asking in a different way.';
    }
    const last: ActionOutcome = outcomes[outcomes.length - 1];
    const detail: string = last.observation.detail.length > 0 ? ` ${last.observation.detail}` : '';
    if (last.observation.success) {
      return `I did that: ${last.observation.summary}.${detail}`;
    }
    return `I stopped at ${last.action.kind}: ${last.observation.summary}${detail}.`;
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
