import { Screen, ScreenSource } from '@hopa/core';
import { A11yBridge } from '@hopa/capability-a11y';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BrowserController } from './BrowserController';
import { RemoteBridge } from './RemoteBridge';
import { RemoteScreenSource } from './RemoteUiCapability';

/**
 * Prefers the PC bridge, then the accessibility tree, then the built-in
 * browser text. It never pretends there is a screen when there is none.
 */
export class CompositeScreenSource implements ScreenSource {
  private browser: BrowserController;
  private remote: RemoteBridge;

  constructor(browser: BrowserController, remote: RemoteBridge) {
    this.browser = browser;
    this.remote = remote;
  }

  async capture(): Promise<Screen> {
    if (this.remote.isConfigured()) {
      hilog.info(0x0000, 'HOPA', 'capture: bridge observe start');
      const screen: Screen = await new RemoteScreenSource(this.remote).capture();
      hilog.info(
        0x0000,
        'HOPA',
        `capture: bridge observe done text=${screen.text.length} nodes=${screen.nodes.length}`
      );
      if (screen.text.length > 0 || screen.nodes.length > 0) {
        return screen;
      }
    }
    if (A11yBridge.get().isAvailable()) {
      hilog.info(0x0000, 'HOPA', 'capture: a11y start');
      const local: Promise<Screen> = A11yBridge.get().capture();
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
