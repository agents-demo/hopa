import { AgentRuntime } from '@hopa/app';

export class LaptopTurn {
  /** Stable across devices: the shared store merges by this. */
  id: string = '';
  role: string = 'user';
  text: string = '';
  at: number = 0;
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
  /** Set before a run so run records can be grouped by the turn that caused them. */
  lastUserTurnId: string = '';
  onTurnStart: (turnId: string) => void = () => {};

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
    user.id = this.newTurnId();
    this.lastUserTurnId = user.id;
    user.at = Date.now();
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
      this.onTurnStart(user.id);
      console.info(`HOPA: send start ${prompt.length} chars`);
      const replyText: string = await this.bounded(this.runtime.run(prompt));
      console.info(`HOPA: run done ${replyText.length} chars, ${this.runtime.lastSteps().length} steps`);
      this.lastLatencyMs = this.runtime.getLastDurationMs();
      this.lastTokens = this.runtime.getLastTokens();
      this.totalTokens += this.lastTokens;
      const reply = new LaptopTurn();
      reply.id = this.newTurnId();
      reply.at = Date.now();
      reply.role = 'assistant';
      // An empty answer used to become an empty bubble: the thinking row
      // vanished and the chat looked like it had ignored the question.
      const answer: string = replyText.trim();
      if (answer.length > 0) {
        reply.text = answer;
      } else if (this.runtime.lastSteps().length > 0) {
        reply.text = 'I did the steps above but did not get a final answer. Ask again and I will continue.';
      } else {
        reply.text = 'I did not get an answer back from the model. Check the key and endpoint under Settings, then ask again.';
      }
      reply.steps = this.runtime.lastSteps().slice();
      this.turns.push(reply);
    } catch (error) {
      console.info(`HOPA: send error ${(error as Error).message}`);
      this.error = `${(error as Error).message}`;
      const reply = new LaptopTurn();
      reply.role = 'assistant';
      reply.text = this.error.length > 0
        ? `I stopped: ${this.error}.`
        : 'I could not reach the model. Check the key and endpoint under Settings.';
      this.turns.push(reply);
    }
    console.info(`HOPA: send finished, turns ${this.turns.length}`);
    this.busy = false;
  }

  /**
   * A run has to end. The model call carries its own socket timeouts, but a
   * loop that keeps retrying can still spin for minutes and leave the shell
   * busy with no answer. After two minutes the run is cancelled and the turn
   * says so, which is better than a composer that never unlocks.
   */
  private async bounded(work: Promise<string>): Promise<string> {
    let timer: number = -1;
    const guard: Promise<string> = new Promise<string>(
      (resolve: (value: string) => void, reject: (reason: Error) => void) => {
        timer = setTimeout(() => {
          console.info('HOPA: bounded timer fired, cancelling');
          if (this.runtime !== undefined) {
            this.runtime.cancel();
          }
          reject(new Error('it ran longer than two minutes, so I stopped it'));
        }, 120000);
      });
    try {
      return await Promise.race([work, guard]);
    } finally {
      clearTimeout(timer);
    }
  }

  /** Ask the last question again, replacing its answer. */
  /** An id the bridge can merge on; collisions across devices are vanishing. */
  private newTurnId(): string {
    return `t\u00b7${Date.now()}\u00b7${Math.floor(Math.random() * 1e6)}`;
  }

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
