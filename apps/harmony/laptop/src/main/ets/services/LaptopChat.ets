import { AgentRuntime } from '@hopa/app';

export class LaptopTurn {
  role: string = 'user';
  text: string = '';
  steps: string[] = [];
}

/**
 * A thin presenter over the shared runtime.
 *
 * The laptop no longer owns a model client or a prompt: it calls the same
 * AgentRuntime the phone uses, with a host that cannot drive this machine.
 */
export class LaptopChat {
  turns: LaptopTurn[] = [];
  busy: boolean = false;
  error: string = '';
  lastLatencyMs: number = 0;
  lastTokens: number = 0;
  totalTokens: number = 0;
  lastQuestion: string = '';

  private runtime: AgentRuntime | undefined = undefined;
  private provider: string = 'deepseek';
  private endpoint: string = '';
  private model: string = '';
  private key: string = '';

  useRuntime(runtime: AgentRuntime): void {
    this.runtime = runtime;
    if (this.key.length > 0) {
      runtime.configureModel(this.provider, this.endpoint, this.key, this.model);
    }
  }

  configure(provider: string, endpoint: string, model: string, key: string): void {
    this.provider = provider.length > 0 ? provider : 'deepseek';
    this.endpoint = endpoint;
    this.model = model;
    this.key = key;
    if (this.runtime !== undefined && this.isReady()) {
      this.runtime.configureModel(this.provider, this.endpoint, this.key, this.model);
    }
  }

  isReady(): boolean {
    return this.runtime !== undefined && this.key.length > 0 &&
      this.endpoint.length > 0 && this.model.length > 0;
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
    try {
      if (this.runtime === undefined || !this.isReady()) {
        throw new Error('no model key yet');
      }
      const replyText: string = await this.runtime.run(prompt);
      this.lastLatencyMs = this.runtime.getLastDurationMs();
      this.lastTokens = this.runtime.getLastTokens();
      this.totalTokens += this.lastTokens;
      const reply = new LaptopTurn();
      reply.role = 'assistant';
      reply.text = replyText;
      reply.steps = this.runtime.lastSteps().slice();
      this.turns.push(reply);
    } catch (error) {
      this.error = `${(error as Error).message}`;
      const reply = new LaptopTurn();
      reply.role = 'assistant';
      reply.text = 'I could not reach the model. Check the key and endpoint under Settings.';
      this.turns.push(reply);
    }
    this.busy = false;
  }

  /** Ask the last question again, replacing its answer. */
  async retry(): Promise<void> {
    if (this.busy || this.turns.length === 0) {
      return;
    }
    while (this.turns.length > 0 && this.turns[this.turns.length - 1].role === 'assistant') {
      this.turns.pop();
    }
    const last: LaptopTurn | undefined = this.turns[this.turns.length - 1];
    if (last === undefined || last.role !== 'user' || last.text.length === 0) {
      return;
    }
    const text: string = last.text;
    this.turns.pop();
    await this.send(text);
  }

  /** Stop the run; the loop closes out and the reply is whatever it reached. */
  cancel(): void {
    if (this.runtime !== undefined) {
      this.runtime.cancel();
    }
  }

  clear(): void {
    this.turns = [];
    this.error = '';
    this.lastQuestion = '';
    this.lastLatencyMs = 0;
    this.lastTokens = 0;
  }
}
