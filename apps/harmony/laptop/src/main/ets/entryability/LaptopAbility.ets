import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA-Laptop';

/**
 * Laptop shell entry point.
 *
 * Optional launch parameters, for a scripted first run:
 *   --ps hopa.laptop_key <key> --ps hopa.laptop_endpoint <url>
 *   --ps hopa.laptop_model <name>
 * The page writes the key straight into Asset Store and then forgets it.
 */
export default class LaptopAbility extends UIAbility {
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
    }
    hilog.info(DOMAIN, TAG, 'laptop ability created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/LaptopIndex', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'content loaded');
    });
  }
}
