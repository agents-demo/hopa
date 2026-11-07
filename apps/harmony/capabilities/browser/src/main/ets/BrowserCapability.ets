import { Action, ActionCapability, Observation } from '@hopa/core';

/**
 * The ArkWeb surface. The entry app owns the `Web` component and implements this
 * interface with its `WebviewController`; the capability stays UI-free.
 */
export interface WebController {
  isReady(): boolean;
  navigate(url: string): Promise<void>;
  readText(): Promise<string>;
  click(target: string): Promise<boolean>;
  type(target: string, text: string): Promise<boolean>;
}

/**
 * Browser capability. It never renders UI; it turns gated actions into controller
 * calls. Network use is gated by the user setting in the entry app.
 */
export class BrowserCapability implements ActionCapability {
  private controller: WebController | undefined = undefined;
  private lastUrl: string = '';
  private lastText: string = '';
  private networkAllowed: boolean = false;
  private opener: ((url: string) => Promise<boolean>) | undefined = undefined;

  setController(controller: WebController): void {
    this.controller = controller;
  }

  /** The entry app opens the Browser page and resolves once its WebView is ready. */
  setSiteOpener(opener: (url: string) => Promise<boolean>): void {
    this.opener = opener;
  }

  setNetworkAllowed(allowed: boolean): void {
    this.networkAllowed = allowed;
  }

  canHandle(kind: string): boolean {
    return kind.startsWith('web.');
  }

  async execute(action: Action): Promise<Observation> {
    if (action.kind === 'web.navigate') {
      if (!this.networkAllowed) {
        return Observation.fail('network is disabled in Settings');
      }
      if (this.controller === undefined) {
        return Observation.fail('no browser controller');
      }
      if (!this.controller.isReady()) {
        if (this.opener === undefined) {
          return Observation.fail('the browser is not open');
        }
        const opened: boolean = await this.opener(action.url);
        if (!opened) {
          return Observation.fail('could not open the browser');
        }
      } else {
        await this.controller.navigate(action.url);
      }
      this.lastUrl = action.url;
      return Observation.ok(`navigated to ${action.url}`);
    }

    if (action.kind === 'web.read') {
      if (this.controller === undefined || !this.controller.isReady()) {
        return Observation.fail('the browser is not open');
      }
      this.lastText = await this.controller.readText();
      return Observation.ok(this.lastText);
    }

    if (action.kind === 'web.click') {
      if (this.controller === undefined || !this.controller.isReady()) {
        return Observation.fail('the browser is not open');
      }
      const clicked: boolean =
        this.controller === undefined ? false : await this.controller.click(action.target);
      return clicked
        ? Observation.ok(`clicked ${action.target}`)
        : Observation.fail(`click failed: ${action.target}`);
    }

    if (action.kind === 'web.type') {
      if (this.controller === undefined || !this.controller.isReady()) {
        return Observation.fail('the browser is not open');
      }
      const typed: boolean =
        this.controller === undefined
          ? false
          : await this.controller.type(action.target, action.text);
      return typed
        ? Observation.ok(`typed into ${action.target}`)
        : Observation.fail(`type failed: ${action.target}`);
    }

    return Observation.fail(`unsupported web action: ${action.kind}`);
  }

  getUrl(): string {
    return this.lastUrl;
  }
}
