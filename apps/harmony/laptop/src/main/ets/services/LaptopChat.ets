import { ModelMessage, ModelRequest, ModelResponse } from '@hopa/core';
import { OpenAiCompatibleClient } from '@hopa/capability-llm';

export class LaptopTurn {
  role: string = 'user';
  text: string = '';
}

/** One conversation on the laptop: model in, words out, no phone involved. */
export class LaptopChat {
  private static readonly SYSTEM: string =
    'You are HOPA, a HarmonyOS on-device agent running on this laptop. ' +
    'Be brief, warm and dry: answer in one to three sentences unless asked for more. ' +
    'Never claim you did something you did not do. This build cannot control other ' +
    'laptop apps yet; if asked, say so plainly instead of pretending. ' +
    'Payments and irreversible actions always ask first.';

  turns: LaptopTurn[] = [];
  busy: boolean = false;
  error: string = '';
  lastLatencyMs: number = 0;
  lastTokens: number = 0;
  totalTokens: number = 0;
  lastQuestion: string = '';

  private endpoint: string = '';
  private model: string = '';
  private key: string = '';

  configure(endpoint: string, model: string, key: string): void {
    this.endpoint = endpoint;
    this.model = model;
    this.key = key;
  }

  isReady(): boolean {
    return this.key.length > 0 && this.endpoint.length > 0 && this.model.length > 0;
  }

  async send(text: string): Promise<void> {
    const prompt: string = text.trim();
    if (prompt.length === 0 || this.busy) {
      return;
    }
    const user = new LaptopTurn();
    user.role = 'user';
    user.text = prompt;
    this.turns.push(user);
    this.busy = true;
    this.error = '';
    this.lastQuestion = prompt;
    const started: number = Date.now();
    try {
      if (!this.isReady()) {
        throw new Error('no model key yet');
      }
      const client = new OpenAiCompatibleClient(this.endpoint, this.key, this.model);
      const request = new ModelRequest();
      request.model = this.model;
      request.temperature = 0.4;
      request.messages.push(new ModelMessage('system', LaptopChat.SYSTEM));
      for (const turn of this.turns) {
        request.messages.push(new ModelMessage(turn.role, turn.text));
      }
      const response: ModelResponse = await client.complete(request);
      this.lastLatencyMs = Date.now() - started;
      this.lastTokens = response.tokens;
      this.totalTokens += response.tokens;
      if (response.error.length > 0 && response.text.length === 0) {
        throw new Error(response.error);
      }
      const reply = new LaptopTurn();
      reply.role = 'assistant';
      reply.text = response.text;
      this.turns.push(reply);
    } catch (error) {
      this.error = `${(error as Error).message}`;
      const reply = new LaptopTurn();
      reply.role = 'assistant';
      reply.text = 'I could not reach the model. Check the key and endpoint under Model.';
      this.turns.push(reply);
    }
    this.busy = false;
  }

  clear(): void {
    this.turns = [];
    this.error = '';
    this.lastQuestion = '';
    this.lastLatencyMs = 0;
    this.lastTokens = 0;
  }
}
