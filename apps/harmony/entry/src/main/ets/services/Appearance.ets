import { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';

/** Applies the saved light/dark preference to the whole app. */
export class Appearance {
  static readonly MODES: string[] = ['System', 'Light', 'Dark'];

  static apply(context: common.UIAbilityContext, mode: string): void {
    try {
      const application = context.getApplicationContext();
      if (mode === 'dark') {
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === 'light') {
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      // The system default remains if the platform rejects the mode.
    }
  }

  static indexOf(mode: string): number {
    if (mode === 'light') {
      return 1;
    }
    if (mode === 'dark') {
      return 2;
    }
    return 0;
  }

  static modeAt(index: number): string {
    if (index === 1) {
      return 'light';
    }
    if (index === 2) {
      return 'dark';
    }
    return 'system';
  }
}
