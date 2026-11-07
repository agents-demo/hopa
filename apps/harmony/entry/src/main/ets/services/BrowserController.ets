import { webview } from '@kit.ArkWeb';
import { WebController } from '@hopa/capability-browser';

/**
 * The entry app's ArkWeb surface, exposed to `BrowserCapability`.
 *
 * Only `https://` navigation is allowed here, in addition to the gate. Page
 * text is read from `document.body.innerText` and is capped so a huge page
 * cannot blow the model context. The page text is also used as the screen for
 * the payment gate when the accessibility extension is unavailable.
 */
export class BrowserController implements WebController {
  private controller: webview.WebviewController | undefined = undefined;
  private loaded: boolean = false;
  private url: string = '';
  private requestedUrl: string = '';
  private pageVersion: number = 0;
  private static readonly MAX_TEXT: number = 20000;

  /** The catalogue asks the browser page to open this URL when it appears. */
  requestUrl(url: string): void {
    if (url.startsWith('https://')) {
      this.requestedUrl = url;
    }
  }

  takeRequestedUrl(): string {
    const url: string = this.requestedUrl;
    this.requestedUrl = '';
    return url;
  }

  attach(controller: webview.WebviewController): void {
    this.controller = controller;
    this.loaded = true;
    this.url = controller.getUrl();
    this.pageVersion += 1;
  }

  /** The Browser page is gone; the old controller must not be reused. */
  detach(): void {
    this.controller = undefined;
    this.loaded = false;
  }

  isReady(): boolean {
    return this.controller !== undefined && this.loaded;
  }

  currentUrl(): string {
    if (this.controller === undefined) {
      return this.url;
    }
    return this.controller.getUrl();
  }

  async navigate(url: string): Promise<void> {
    if (!url.startsWith('https://')) {
      throw new Error('only https URLs are allowed');
    }
    if (this.controller === undefined) {
      throw new Error('browser is not attached');
    }
    const before: number = this.pageVersion;
    this.controller.loadUrl(url);
    this.url = url;
    await this.waitForPage(before, 10000);
  }

  async readText(): Promise<string> {
    if (this.controller === undefined) {
      return '';
    }
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const script: string =
          '(function(){' +
          'var t = document.body ? document.body.innerText : "";' +
          'var title = document.title || "";' +
          `if (t.length > ${BrowserController.MAX_TEXT}) { t = t.slice(0, ${BrowserController.MAX_TEXT}); }` +
          'return "URL: " + location.href + "\\nTITLE: " + title + "\\n\\n" + t;' +
          '})()';
        const result: webview.JsMessageExt = await this.controller.runJavaScriptExt(script);
        const text: string = result.getString();
        if (text.length > 0) {
          return text;
        }
      } catch (error) {
        // Retry once; a page that is still loading returns nothing.
      }
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 300);
      });
    }
    return '';
  }

  /** Page text used as the observation when a11y is unavailable. */
  async pageText(): Promise<string> {
    if (!this.isReady()) {
      return '';
    }
    return this.readText();
  }

  async click(target: string): Promise<boolean> {
    if (this.controller === undefined) {
      return false;
    }
    const needle: string = JSON.stringify(target.toLowerCase());
    const before: number = this.pageVersion;
    try {
      const script: string =
        '(function(){' +
        `var needle = ${needle};` +
        'function matches(e){' +
        '  var t = (e.innerText || e.value || e.getAttribute("aria-label") || "").trim().toLowerCase();' +
        '  return t === needle || t.indexOf(needle) >= 0;' +
        '}' +
        'var els = Array.prototype.slice.call(document.querySelectorAll("a,button,input,[role=button],[onclick]"));' +
        'var el = els.find(matches);' +
        'if (!el) { el = Array.prototype.slice.call(document.querySelectorAll("*")).find(matches); }' +
        'if (!el) { return "not_found"; }' +
        'el.scrollIntoView({block:"center"});' +
        'el.click();' +
        'return "clicked";' +
        '})()';
      const result: webview.JsMessageExt = await this.controller.runJavaScriptExt(script);
      const clicked: boolean = result.getString() === 'clicked';
      if (clicked) {
        await this.waitForPage(before, 8000);
      }
      return clicked;
    } catch (error) {
      return false;
    }
  }

  private waitForPage(before: number, timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      const started: number = Date.now();
      const tick = (): void => {
        if (this.pageVersion > before || Date.now() - started >= timeoutMs) {
          resolve();
          return;
        }
        setTimeout(tick, 100);
      };
      tick();
    });
  }

  async type(target: string, text: string): Promise<boolean> {
    if (this.controller === undefined) {
      return false;
    }
    const needle: string = JSON.stringify(target.toLowerCase());
    const value: string = JSON.stringify(text);
    try {
      const script: string =
        '(function(){' +
        `var needle = ${needle};` +
        `var value = ${value};` +
        'function field(){' +
        '  var byLabel = Array.prototype.slice.call(document.querySelectorAll("input,textarea")).find(function(e){' +
        '    var a = (e.getAttribute("placeholder") || e.getAttribute("aria-label") || e.getAttribute("name") || "").toLowerCase();' +
        '    return a.indexOf(needle) >= 0;' +
        '  });' +
        '  return byLabel || document.querySelector("input,textarea");' +
        '}' +
        'var el = field();' +
        'if (!el) { return "not_found"; }' +
        'el.focus();' +
        'var proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;' +
        'var setter = Object.getOwnPropertyDescriptor(proto, "value").set;' +
        'setter.call(el, value);' +
        'el.dispatchEvent(new Event("input", {bubbles:true}));' +
        'el.dispatchEvent(new Event("change", {bubbles:true}));' +
        'return "typed";' +
        '})()';
      const result: webview.JsMessageExt = await this.controller.runJavaScriptExt(script);
      return result.getString() === 'typed';
    } catch (error) {
      return false;
    }
  }
}
