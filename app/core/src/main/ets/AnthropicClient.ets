import { http } from '@kit.NetworkKit';
import { ModelClient, ModelRequest, ModelResponse } from './ModelClient';

class AnthropicMessage {
  role: string = '';
  content: string = '';
}

class AnthropicBody {
  model: string = '';
  max_tokens: number = 1024;
  temperature: number = 0.2;
  system: string = '';
  messages: AnthropicMessage[] = [];
}

class AnthropicBlock {
  type: string = '';
  text: string = '';
}

class AnthropicResponse {
  content: AnthropicBlock[] = [];
}

/**
 * Anthropic Messages API client. It reuses the same `ModelClient` contract and
 * moves the system message into Anthropic's top-level `system` field.
 */
export class AnthropicClient implements ModelClient {
  private endpoint: string;
  private apiKey: string;
  private model: string;

  constructor(endpoint: string, apiKey: string, model: string) {
    this.endpoint = endpoint.length > 0 ? endpoint : 'https://api.anthropic.com';
    this.apiKey = apiKey;
    this.model = model;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const body = new AnthropicBody();
    body.model = this.model;
    body.temperature = request.temperature;
    body.max_tokens = 1024;
    for (const message of request.messages) {
      if (message.role === 'system') {
        body.system = body.system.length > 0 ? `${body.system}\n${message.content}` : message.content;
        continue;
      }
      const item = new AnthropicMessage();
      item.role = message.role === 'assistant' ? 'assistant' : 'user';
      item.content = message.content;
      body.messages.push(item);
    }

    const client = http.createHttp();
    const result = new ModelResponse();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 60000
      };
      const response = await client.request(`${this.endpoint}/v1/messages`, options);
      if (response.responseCode !== 200) {
        result.error = `HTTP ${response.responseCode}`;
        return result;
      }
      const parsed = JSON.parse(`${response.result}`) as AnthropicResponse;
      const texts: string[] = [];
      for (const block of parsed.content) {
        if (block.type === 'text' && block.text.length > 0) {
          texts.push(block.text);
        }
      }
      if (texts.length === 0) {
        result.error = 'model returned no text block';
      } else {
        result.text = texts.join('\n');
      }
      return result;
    } catch (error) {
      result.error = `${error}`;
      return result;
    } finally {
      client.destroy();
    }
  }
}
