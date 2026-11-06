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
}

/** The only model abstraction the agent loop depends on. */
export interface ModelClient {
  complete(request: ModelRequest): Promise<ModelResponse>;
}

/** Deterministic model used by tests and by the benchmark harness. */
export class StubModelClient implements ModelClient {
  private reply: string;

  constructor(reply: string = '{"kind":"finish"}') {
    this.reply = reply;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const response = new ModelResponse();
    response.text = this.reply;
    return response;
  }
}
