import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { Appearance } from '../services/Appearance';
import { HopaForeground } from '../services/HopaForeground';
import { AgentService } from '../services/AgentService';
import { SettingsStore, StoredSettings } from '../services/SettingsStore';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyLaunchConfig(want);
    hilog.info(DOMAIN, TAG, 'HOPA entry ability created');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyLaunchConfig(want);
  }

  /**
   * Optional automation hook: `aa start ... --ps hopa.* value` supplies the
   * model and bridge settings for this run. The API key stays in memory.
   */
  private applyLaunchConfig(want: Want): void {
    const params = want.parameters;
    if (!params) {
      return;
    }
    const read = (key: string): string => {
      const value = params[key];
      return typeof value === 'string' ? value : '';
    };
    const provider = read('hopa.provider');
    const baseUrl = read('hopa.base_url');
    const model = read('hopa.model');
    const apiKey = read('hopa.api_key');
    const bridgeUrl = read('hopa.bridge_url');
    const bridgeToken = read('hopa.bridge_token');

    if (baseUrl.length > 0 || model.length > 0 || apiKey.length > 0) {
      AgentService.get().configureModel(
        provider.length > 0 ? provider : 'openai',
        baseUrl,
        apiKey,
        model,
        6
      );
    }
    if (bridgeUrl.length > 0 && bridgeToken.length > 0) {
      AgentService.get().configureBridge(bridgeUrl, bridgeToken);
    }

    SettingsStore.load(this.context).then((stored: StoredSettings) => {
      if (provider.length > 0) {
        stored.provider = provider;
      }
      if (baseUrl.length > 0) {
        stored.endpoint = baseUrl;
      }
      if (model.length > 0) {
        stored.model = model;
      }
      if (bridgeUrl.length > 0) {
        stored.bridgeUrl = bridgeUrl;
      }
      if (bridgeToken.length > 0) {
        stored.bridgeToken = bridgeToken;
      }
      return SettingsStore.save(this.context, stored);
    }).catch(() => {
      hilog.warn(DOMAIN, TAG, 'Failed to persist launch config');
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    Appearance.loadAccent(this.context).catch(() => {
      // The brand colour remains when the wallpaper cannot be read.
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded');
      // The page is alive only from here on, so this is the reliable place to
      // switch the window to RESIZE. Left at the default OFFSET, the whole page
      // (header included) is pushed up when the keyboard opens.
      try {
        const mainWindow: window.Window = windowStage.getMainWindowSync();
        mainWindow.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
        hilog.info(DOMAIN, TAG, 'keyboard avoid mode: RESIZE');
      } catch (error) {
        hilog.warn(DOMAIN, TAG, `keyboard avoid mode failed: ${error}`);
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Window stage destroyed');
  }

  onForeground(): void {
    HopaForeground.active = true;
    hilog.info(DOMAIN, TAG, 'Foreground');
  }

  onBackground(): void {
    HopaForeground.active = false;
    hilog.info(DOMAIN, TAG, 'Background');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Destroyed');
  }
}
