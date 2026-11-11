import { ModelClient, ModelRequest, ModelResponse } from '@hopa/core';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Adds coarse timing breadcrumbs to the model call (hilog tag HOPA). */
export class LoggingModelClient implements ModelClient {
  private inner: ModelClient;

  constructor(inner: ModelClient) {
    this.inner = inner;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    hilog.info(0x0000, 'HOPA', `model: start messages=${request.messages.length}`);
    try {
      const response: ModelResponse = await this.inner.complete(request);
      hilog.info(
        0x0000,
        'HOPA',
        `model: done tokens=${response.tokens} error=${response.error.length}`
      );
      return response;
    } catch (error) {
      hilog.error(0x0000, 'HOPA', `model: threw ${error}`);
      throw new Error(`${error}`);
    }
  }
}
