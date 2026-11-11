import { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { wallpaper } from '@kit.BasicServicesKit';

/** Applies the saved light/dark preference to the whole app. */
export class Appearance {
  static readonly MODES: string[] = ['System', 'Light', 'Dark'];
  static readonly ACCENT_KEY: string = 'hopa.accent';

  /**
   * The wallpaper's dominant colour, tuned into a usable accent.
   *
   * `getColors` is legacy but still served by the platform; when it is missing
   * the fixed brand colour stays in place.
   */
  static async loadAccent(context: common.UIAbilityContext): Promise<string> {
    try {
      const colors = await wallpaper.getColors(wallpaper.WallpaperType.WALLPAPER_SYSTEM);
      if (colors.length === 0) {
        return '';
      }
      const color = colors[0];
      const accent: string = Appearance.tune(color.red, color.green, color.blue);
      AppStorage.setOrCreate<string>(Appearance.ACCENT_KEY, accent);
      return accent;
    } catch (error) {
      return '';
    }
  }

  /** Keep the wallpaper hue, but make it readable as a button colour. */
  private static tune(red: number, green: number, blue: number): string {
    const r: number = red / 255;
    const g: number = green / 255;
    const b: number = blue / 255;
    const max: number = Math.max(r, Math.max(g, b));
    const min: number = Math.min(r, Math.min(g, b));
    const lightness: number = (max + min) / 2;
    const delta: number = max - min;
    let hue: number = 0;
    let saturation: number = 0;
    if (delta > 0) {
      saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min);
      if (max === r) {
        hue = (g - b) / delta + (g < b ? 6 : 0);
      } else if (max === g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue = hue / 6;
    }
    const tunedSat: number = Math.max(saturation, 0.55);
    const tunedLight: number = Math.min(Math.max(lightness, 0.46), 0.58);
    return Appearance.hslToHex(hue, tunedSat, tunedLight);
  }

  private static hslToHex(hue: number, saturation: number, lightness: number): string {
    const hue2rgb = (p: number, q: number, t: number): number => {
      let value: number = t;
      if (value < 0) {
        value += 1;
      }
      if (value > 1) {
        value -= 1;
      }
      if (value < 1 / 6) {
        return p + (q - p) * 6 * value;
      }
      if (value < 1 / 2) {
        return q;
      }
      if (value < 2 / 3) {
        return p + (q - p) * (2 / 3 - value) * 6;
      }
      return p;
    };
    const q: number = lightness < 0.5
      ? lightness * (1 + saturation)
      : lightness + saturation - lightness * saturation;
    const p: number = 2 * lightness - q;
    const r: number = Math.round(hue2rgb(p, q, hue + 1 / 3) * 255);
    const g: number = Math.round(hue2rgb(p, q, hue) * 255);
    const b: number = Math.round(hue2rgb(p, q, hue - 1 / 3) * 255);
    const hex = (value: number): string => {
      const text: string = value.toString(16);
      return text.length === 1 ? `0${text}` : text;
    };
    return `#${hex(r)}${hex(g)}${hex(b)}`;
  }

  static apply(context: common.UIAbilityContext, mode: string): void {
    let dark: boolean = false;
    try {
      const application = context.getApplicationContext();
      if (mode === 'dark') {
        dark = true;
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === 'light') {
        dark = false;
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        dark = context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        application.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      // The system default remains if the platform rejects the mode.
    }
    // Page tints are strings, not resources, so they need the resolved mode.
    AppStorage.setOrCreate<boolean>('hopa.dark', dark);
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
