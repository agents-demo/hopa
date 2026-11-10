import { webview } from '@kit.ArkWeb';
import { RuntimeBrowser } from '@hopa/app';

/**
 * HOPA's own browser, as a capability.
 *
 * The desktop has no accessibility tree and no screen permission, but a page
 * HOPA opened itself is not a permission question: the Web component exposes
 * its DOM to us. That is the honest way for the laptop to "read the web".
 *
 * The controller only exists while the Browser pane is mounted; before that the
 * capability says it is not ready and the runtime refuses page actions instead
 * of pretending.
 */
export class LaptopBrowser implements RuntimeBrowser {
  private controller: webview.WebviewController | undefined = undefined;
  private url: string = '';
  private title: string = '';

  attach(controller: webview.WebviewController): void {
    this.controller = controller;
  }

  detach(): void {
    this.controller = undefined;
  }

  isReady(): boolean {
    return this.controller !== undefined;
  }

  currentUrl(): string {
    return this.url;
  }

  currentTitle(): string {
    return this.title;
  }

  /** The visible text of the page, as the reader would see it. */
  async pageText(): Promise<string> {
    const controller = this.controller;
    if (controller === undefined) {
      return '';
    }
    try {
      const text: string = await controller.runJavaScript('document.body.innerText');
      return typeof text === 'string' ? text : '';
    } catch (error) {
      return '';
    }
  }

  /** Navigation is requested by the shell, but the URL belongs to the page. */
  note(url: string, title: string): void {
    this.url = url;
    this.title = title;
  }
}
