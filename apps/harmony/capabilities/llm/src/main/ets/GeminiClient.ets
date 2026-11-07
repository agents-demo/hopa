import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';
import { ModelClient, ModelRequest, ModelResponse } from '@hopa/core';

class GeminiPart {
  text: string = '';
}

class GeminiContent {
  role: string = '';
  parts: GeminiPart[] = [];
}

class GeminiInstruction {
  parts: GeminiPart[] = [];
}

class GeminiGenerationConfig {
  temperature: number = 0.2;
}

class GeminiBody {
  contents: GeminiContent[] = [];
  systemInstruction: GeminiInstruction | undefined = undefined;
  generationConfig: GeminiGenerationConfig = new GeminiGenerationConfig();
}

class GeminiCandidateContent {
  parts: GeminiPart[] = [];
}

class GeminiCandidate {
  content: GeminiCandidateContent = new GeminiCandidateContent();
}

class GeminiResponse {
  candidates: GeminiCandidate[] = [];
  usageMetadata: GeminiUsage = new GeminiUsage();
}

class GeminiUsage {
  totalTokenCount: number = 0;
}

/**
 * Google Gemini `generateContent` client. Assistant turns become `model`
 * turns; the system message becomes `systemInstruction`.
 */
export class GeminiClient implements ModelClient {
  private endpoint: string;
  private apiKey: string;
  private model: string;

  constructor(endpoint: string, apiKey: string, model: string) {
    this.endpoint = endpoint.length > 0 ? endpoint : 'https://generativelanguage.googleapis.com';
    this.apiKey = apiKey;
    this.model = model;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const body = new GeminiBody();
    body.generationConfig.temperature = request.temperature;
    const systemParts: GeminiPart[] = [];
    for (const message of request.messages) {
      if (message.role === 'system') {
        const part = new GeminiPart();
        part.text = message.content;
        systemParts.push(part);
        continue;
      }
      const content = new GeminiContent();
      content.role = message.role === 'assistant' ? 'model' : 'user';
      const part = new GeminiPart();
      part.text = message.content;
      content.parts.push(part);
      body.contents.push(content);
    }
    if (systemParts.length > 0) {
      const instruction = new GeminiInstruction();
      instruction.parts = systemParts;
      body.systemInstruction = instruction;
    }

    const client = http.createHttp();
    const result = new ModelResponse();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'x-goog-api-key': this.apiKey
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 60000
      };
      const url: string =
        `${this.endpoint}/v1beta/models/${this.model}:generateContent`;
      const response = await client.request(url, options);
      if (response.responseCode !== 200) {
        result.error = `HTTP ${response.responseCode}`;
        return result;
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as GeminiResponse;
      result.tokens = parsed.usageMetadata.totalTokenCount;
      if (parsed.candidates.length === 0 || parsed.candidates[0].content.parts.length === 0) {
        result.error = 'model returned no candidate';
        return result;
      }
      const texts: string[] = [];
      for (const part of parsed.candidates[0].content.parts) {
        if (part.text.length > 0) {
          texts.push(part.text);
        }
      }
      result.text = texts.join('\n');
      return result;
    } catch (error) {
      result.error = `${error}`;
      return result;
    } finally {
      client.destroy();
    }
  }
}
