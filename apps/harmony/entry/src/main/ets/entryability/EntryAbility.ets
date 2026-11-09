import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { Appearance } from '../services/Appearance';
import { HopaForeground } from '../services/HopaForeground';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'HOPA entry ability created');
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
