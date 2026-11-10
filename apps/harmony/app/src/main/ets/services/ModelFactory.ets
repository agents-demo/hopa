import { ModelClient } from '@hopa/core';
import { AnthropicClient, GeminiClient, OpenAiCompatibleClient } from '@hopa/capability-llm';

/** Maps a provider name to its HTTP client. The key stays in memory. */
export class ModelFactory {
  static create(provider: string, endpoint: string, apiKey: string, modelName: string): ModelClient {
    if (provider === 'anthropic') {
      return new AnthropicClient(endpoint, apiKey, modelName);
    }
    if (provider === 'gemini') {
      return new GeminiClient(endpoint, apiKey, modelName);
    }
    return new OpenAiCompatibleClient(endpoint, apiKey, modelName);
  }
}
