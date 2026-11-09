import { webview } from '@kit.ArkWeb';
import { SandboxBridge } from '@hopa/capability-sandbox';

/**
 * Executes user JavaScript in an isolated `about:blank` ArkWeb page.
 *
 * No device APIs, files or network are exposed to the script; it can only use
 * the page's own JS engine. Python is not bundled, so `language` must be
 * `javascript` or `js`.
 */
export class JsSandboxBridge implements SandboxBridge {
  private controller: webview.WebviewController | undefined = undefined;

  constructor(controller?: webview.WebviewController) {
    this.controller = controller;
  }

  attach(controller: webview.WebviewController): void {
    this.controller = controller;
  }

  isReady(): boolean {
    return this.controller !== undefined;
  }

  async run(script: string, language: string): Promise<string> {
    const lang: string = language.toLowerCase();
    if (lang !== 'javascript' && lang !== 'js') {
      throw new Error('only JavaScript is available; Python/WASM is not bundled');
    }
    if (this.controller === undefined) {
      throw new Error('sandbox page is not ready');
    }
    const source: string = JSON.stringify(script);
    const wrapped: string =
      '(function(){' +
      'try {' +
      `var __result = eval(${source});` +
      'return JSON.stringify({ok:true, value:String(__result)});' +
      '} catch (e) {' +
      'return JSON.stringify({ok:false, error:String(e)});' +
      '}' +
      '})()';
    const message: webview.JsMessageExt = await this.controller.runJavaScriptExt(wrapped);
    return message.getString();
  }
}
