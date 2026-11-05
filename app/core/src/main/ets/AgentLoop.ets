import { Action, ActionOutcome } from './Types';
import { ActionExecutor } from './ActionExecutor';
import { ModelClient, ModelMessage, ModelRequest, ModelResponse } from './ModelClient';

class ActionPayload {
  kind: string = '';
  target: string = '';
  text: string = '';
  url: string = '';
  isPayment: boolean = false;
}

/**
 * A minimal agent loop: ask the model for one action at a time, execute it
 * through the gate, and feed the observation back. Production code will add
 * planning, memory, and richer verification; the gate must not change.
 */
export class AgentLoop {
  private executor: ActionExecutor;
  private model: ModelClient;
  private maxSteps: number;

  constructor(executor: ActionExecutor, model: ModelClient, maxSteps: number = 10) {
    this.executor = executor;
    this.model = model;
    this.maxSteps = maxSteps;
  }

  async run(goal: string): Promise<ActionOutcome[]> {
    const outcomes: ActionOutcome[] = [];
    const messages: ModelMessage[] = [
      new ModelMessage(
        'system',
        'You are HOPA, a phone agent. Propose exactly one JSON action at a time. ' +
          'Payments always require the user; never try to bypass approval.'
      ),
      new ModelMessage('user', goal)
    ];

    for (let step = 0; step < this.maxSteps; step++) {
      const request = new ModelRequest();
      request.messages = messages;
      const response: ModelResponse = await this.model.complete(request);
      if (response.text.trim().length === 0) {
        break;
      }

      const action: Action | undefined = this.parseAction(response.text);
      if (action === undefined) {
        break;
      }

      const outcome: ActionOutcome = await this.executor.execute(action);
      outcomes.push(outcome);

      messages.push(new ModelMessage('assistant', response.text));
      messages.push(
        new ModelMessage(
          'user',
          `Observation: ${outcome.observation.summary} ${outcome.observation.detail}`
        )
      );

      if (!outcome.executed || !outcome.observation.success) {
        break;
      }
    }

    return outcomes;
  }

  private parseAction(text: string): Action | undefined {
    try {
      const payload = JSON.parse(text) as ActionPayload;
      if (payload.kind.length === 0) {
        return undefined;
      }
      const action = new Action(payload.kind);
      action.target = payload.target;
      action.text = payload.text;
      action.url = payload.url;
      action.isPayment = payload.isPayment;
      return action;
    } catch (error) {
      return undefined;
    }
  }
}
