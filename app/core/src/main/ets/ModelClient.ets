export class ModelMessage {
  role: string;
  content: string;

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

export class ModelRequest {
  messages: ModelMessage[] = [];
  model: string = '';
  temperature: number = 0.2;
}

export class ModelResponse {
  text: string = '';
  error: string = '';
  tokens: number = 0;
}

/** The only model abstraction the agent loop depends on. */
export interface ModelClient {
  complete(request: ModelRequest): Promise<ModelResponse>;
}

/** Deterministic model used by tests and by the benchmark harness. */
export class StubModelClient implements ModelClient {
  private reply: string;
  private tokens: number;

  constructor(reply: string = '{"kind":"finish"}', tokens: number = 0) {
    this.reply = reply;
    this.tokens = tokens;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const response = new ModelResponse();
    response.text = this.reply;
    response.tokens = this.tokens;
    return response;
  }
}
