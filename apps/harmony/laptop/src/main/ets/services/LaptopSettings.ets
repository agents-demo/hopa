import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

/** Endpoint and model name; the key itself lives in Asset Store. */
export class LaptopSettings {
  private static readonly NAME: string = 'hopa_laptop';

  endpoint: string = 'https://api.deepseek.com/v1';
  model: string = 'deepseek-v4-flash';

  static async load(context: Context): Promise<LaptopSettings> {
    const settings = new LaptopSettings();
    try {
      const store = await preferences.getPreferences(context, LaptopSettings.NAME);
      const endpoint = await store.get('endpoint', settings.endpoint);
      const model = await store.get('model', settings.model);
      if (typeof endpoint === 'string' && endpoint.length > 0) {
        settings.endpoint = endpoint;
      }
      if (typeof model === 'string' && model.length > 0) {
        settings.model = model;
      }
    } catch (error) {
      // First run keeps the defaults.
    }
    return settings;
  }

  async save(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, LaptopSettings.NAME);
      await store.put('endpoint', this.endpoint);
      await store.put('model', this.model);
      await store.flush();
    } catch (error) {
      // Persistence is best effort.
    }
  }
}
