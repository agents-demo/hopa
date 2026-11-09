import { vibrator } from '@kit.SensorServiceKit';

/** Short, honest haptics: a tap for the mark, attention for an approval. */
export class Haptics {
  static tap(): void {
    try {
      const effect: vibrator.VibrateEffect = { type: 'time', duration: 30 };
      const attribute: vibrator.VibrateAttribute = { id: 0, usage: 'notification' };
      vibrator.startVibration(effect, attribute).catch(() => {
        // Haptics are optional; a device may not have a vibrator.
      });
    } catch (error) {
      // The permission can be missing on an unusual build.
    }
  }

  static attention(): void {
    try {
      const effect: vibrator.VibrateEffect = { type: 'time', duration: 70 };
      const attribute: vibrator.VibrateAttribute = { id: 0, usage: 'notification' };
      vibrator.startVibration(effect, attribute).catch(() => {});
      setTimeout(() => {
        try {
          vibrator.startVibration(
            { type: 'time', duration: 45 },
            { id: 0, usage: 'notification' }
          ).catch(() => {});
        } catch (error) {
          // Best effort.
        }
      }, 130);
    } catch (error) {
      // Best effort.
    }
  }
}
