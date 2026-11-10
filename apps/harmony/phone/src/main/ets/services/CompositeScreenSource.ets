import { RuntimeBrowser, RuntimeBridge } from '@hopa/app';
import { Screen, ScreenSource } from '@hopa/core';
import { AccessibilityBridge } from '@hopa/capability-accessibility';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BrowserController } from './BrowserController';
import { BridgeClient } from './BridgeClient';
import { BridgeScreenSource } from './RemoteUiCapability';

/**
 * Prefers the PC bridge, then the accessibility tree, then the built-in
 * browser text. It never pretends there is a screen when there is none.
 */
export class CompositeScreenSource implements ScreenSource {
  private browser: RuntimeBrowser;
  private bridge: BridgeClient;

  constructor(browser: RuntimeBrowser, bridge: BridgeClient) {
    this.browser = browser;
    this.bridge = bridge;
  }

  async capture(): Promise<Screen> {
    if (this.bridge.isConfigured()) {
      hilog.info(0x0000, 'HOPA', 'capture: bridge observe start');
      const screen: Screen = await new BridgeScreenSource(this.bridge).capture();
      hilog.info(
        0x0000,
        'HOPA',
        `capture: bridge observe done text=${screen.text.length} nodes=${screen.nodes.length}`
      );
      if (screen.text.length > 0 || screen.nodes.length > 0) {
        return screen;
      }
    }
    if (AccessibilityBridge.get().isAvailable()) {
      hilog.info(0x0000, 'HOPA', 'capture: a11y start');
      const local: Promise<Screen> = AccessibilityBridge.get().capture();
      const guard: Promise<Screen> = new Promise<Screen>((resolve: (value: Screen) => void) => {
        setTimeout(() => {
          resolve(new Screen(''));
        }, 4000);
      });
      return Promise.race([local, guard]);
    }
    return new Screen(await this.browser.pageText());
  }
}
