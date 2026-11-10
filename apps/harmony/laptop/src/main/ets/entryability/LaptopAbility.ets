import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA-Laptop';

class SavedWindow {
  w: number = 0;
  h: number = 0;
  x: number = 0;
  y: number = 0;
}

/**
 * Laptop shell entry point.
 *
 * Optional launch parameters, for a scripted first run:
 *   --ps hopa.laptop_key <key> --ps hopa.laptop_endpoint <url>
 *   --ps hopa.laptop_model <name> --ps hopa.bridge_url <url> --ps hopa.bridge_key <key>
 * The page writes the key straight into Asset Store and then forgets it.
 */
export default class LaptopAbility extends UIAbility {
  private saveTimer: number = -1;
  private pending: SavedWindow = new SavedWindow();

  /** The window comes back where it was: size in the store, position too. */
  private async restoreWindow(win: window.Window): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.context, 'hopa_laptop');
      const raw = await store.get('win_state', '');
      if (typeof raw === 'string' && raw.length > 2) {
        const saved = JSON.parse(raw) as SavedWindow;
        if (saved.w > 400 && saved.h > 300) {
          await win.resize(saved.w, saved.h);
          await win.moveWindowTo(saved.x, saved.y);
        }
      }
      win.on('windowRectChange', (options: window.RectChangeOptions) => {
        this.pending.w = options.rect.width;
        this.pending.h = options.rect.height;
        this.pending.x = options.rect.left;
        this.pending.y = options.rect.top;
        this.scheduleWindowSave();
      });
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'window state unavailable');
    }
  }

  private scheduleWindowSave(): void {
    if (this.saveTimer >= 0) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.persistWindow();
    }, 900);
  }

  private async persistWindow(): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.context, 'hopa_laptop');
      await store.put('win_state', JSON.stringify(this.pending));
      await store.flush();
    } catch (error) {
      // Remembering the window is a convenience.
    }
  }
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const params = want.parameters;
    if (params !== undefined) {
      const key = params['hopa.laptop_key'];
      const endpoint = params['hopa.laptop_endpoint'];
      const model = params['hopa.laptop_model'];
      if (typeof key === 'string' && key.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.key', key);
      }
      if (typeof endpoint === 'string' && endpoint.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.endpoint', endpoint);
      }
      if (typeof model === 'string' && model.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.model', model);
      }
      const linkUrl = params['hopa.link_url'];
      const linkKey = params['hopa.link_key'];
      if (typeof linkUrl === 'string' && linkUrl.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.linkUrl', linkUrl);
      }
      if (typeof linkKey === 'string' && linkKey.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.linkKey', linkKey);
      }
      const bridgeUrl = params['hopa.bridge_url'];
      const bridgeKey = params['hopa.bridge_key'];
      if (typeof bridgeUrl === 'string' && bridgeUrl.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.bridgeUrl', bridgeUrl);
      }
      if (typeof bridgeKey === 'string' && bridgeKey.length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.bridgeToken', bridgeKey);
      }
      const demo = params['hopa.approval_demo'];
      if (typeof demo === 'string' && demo === '1') {
        AppStorage.setOrCreate<string>('hopa.laptop.demoApproval', '1');
      }
      const fresh = params['hopa.new'];
      if (typeof fresh === 'string' && fresh === '1') {
        AppStorage.setOrCreate<string>('hopa.laptop.new', '1');
      }
      const ask = params['hopa.ask'];
      if (typeof ask === 'string' && ask.trim().length > 0) {
        AppStorage.setOrCreate<string>('hopa.laptop.pending', ask.trim());
      }
    }
    const uri: string = want.uri ?? '';
    if (uri.startsWith('hopa://ask')) {
      const marker: number = uri.indexOf('text=');
      if (marker >= 0) {
        let text: string = uri.substring(marker + 5);
        try {
          text = decodeURIComponent(text.replace(/\+/g, ' '));
        } catch (error) {
          // Keep the raw text when the encoding is odd.
        }
        if (text.trim().length > 0) {
          AppStorage.setOrCreate<string>('hopa.laptop.pending', text.trim());
        }
      }
    }
    hilog.info(DOMAIN, TAG, 'laptop ability created');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const params = want.parameters;
    const ask = params !== undefined ? params['hopa.ask'] : undefined;
    if (typeof ask === 'string' && ask.trim().length > 0) {
      AppStorage.setOrCreate<string>('hopa.laptop.pending', ask.trim());
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const early: window.Window = windowStage.getMainWindowSync();
      early.setWindowDecorVisible(false);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'early decor call failed');
    }
    windowStage.loadContent('pages/LaptopIndex', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'content loaded');
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      // The platform hides the title text and icon but keeps its strip and
      // buttons; forcing the height throws on HarmonyOS 7, so do not try.
      try {
        mainWindow.setWindowDecorVisible(false);
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'title text cannot be hidden');
      }
      try {
        mainWindow.setWindowBackgroundColor('#F7F4EE');
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'window background not set');
      }
      let decorHeight: number = -1;
      try {
        decorHeight = mainWindow.getWindowDecorHeight();
      } catch (error) {
        decorHeight = -1;
      }
      AppStorage.setOrCreate<boolean>('hopa.decorHidden', decorHeight === 0);
      hilog.info(DOMAIN, TAG, 'decor height: %{public}d', decorHeight);
      this.restoreWindow(mainWindow);
    });
  }
}
