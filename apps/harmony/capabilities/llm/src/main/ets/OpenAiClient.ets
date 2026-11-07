import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';
import { ModelClient, ModelMessage, ModelRequest, ModelResponse } from '@hopa/core';

class OpenAiMessage {
  role: string = '';
  content: string = '';
}

class OpenAiRequestBody {
  model: string = '';
  temperature: number = 0.2;
  messages: OpenAiMessage[] = [];
}

class OpenAiChoiceMessage {
  content: string = '';
}

class OpenAiChoice {
  message: OpenAiChoiceMessage = new OpenAiChoiceMessage();
}

class OpenAiResponseBody {
  choices: OpenAiChoice[] = [];
  usage: OpenAiUsage = new OpenAiUsage();
}

class OpenAiUsage {
  total_tokens: number = 0;
}

/**
 * OpenAI-compatible chat-completions client.
 *
 * The API key is supplied by the caller at runtime and must be stored in the
 * app's secure settings, never in the repository.
 */
export class OpenAiCompatibleClient implements ModelClient {
  private endpoint: string;
  private apiKey: string;
  private model: string;

  constructor(endpoint: string, apiKey: string, model: string) {
    this.endpoint = endpoint;
    this.apiKey = apiKey;
    this.model = model;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const body = new OpenAiRequestBody();
    body.model = this.model;
    body.temperature = request.temperature;
    body.messages = request.messages.map((message: ModelMessage) => {
      const item = new OpenAiMessage();
      item.role = message.role;
      item.content = message.content;
      return item;
    });

    const client = http.createHttp();
    const result = new ModelResponse();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 60000
      };
      const response = await client.request(`${this.endpoint}/chat/completions`, options);
      if (response.responseCode !== 200) {
        result.error = `HTTP ${response.responseCode}`;
        return result;
      }

      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as OpenAiResponseBody;
      if (parsed.usage !== undefined) {
        result.tokens = parsed.usage.total_tokens;
      }
      if (parsed.choices.length > 0) {
        result.text = parsed.choices[0].message.content;
      } else {
        result.error = 'model returned no choices';
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
