import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { SettingsStore, StoredSettings } from '@hopa/app';

/**
 * First run on the laptop: carry the pre-shared settings over, and default a
 * fresh machine to the same provider the phone uses.
 *
 * The shared schema defaults to OpenAI; HOPA ships DeepSeek-first, so a laptop
 * that has never been configured should not start on an endpoint its key will
 * never work against.
 */
export class LaptopFirstRun {
  static async ensure(context: Context): Promise<StoredSettings> {
    const stored: StoredSettings = await SettingsStore.load(context);
    let changed: boolean = false;
    try {
      const legacy = await preferences.getPreferences(context, 'hopa_laptop');
      const endpoint = await legacy.get('endpoint', '');
      const model = await legacy.get('model', '');
      if (typeof endpoint === 'string' && endpoint.length > 0 && endpoint !== stored.endpoint) {
        stored.provider = 'deepseek';
        stored.endpoint = endpoint;
        changed = true;
      }
      if (typeof model === 'string' && model.length > 0 && model !== stored.model) {
        stored.model = model;
        changed = true;
      }
    } catch (error) {
      // No legacy store: a clean first run.
    }
    if (!changed && stored.endpoint.indexOf('api.openai.com') >= 0) {
      stored.provider = 'deepseek';
      stored.endpoint = 'https://api.deepseek.com/v1';
      stored.model = 'deepseek-v4-flash';
      changed = true;
    }
    if (changed) {
      await SettingsStore.save(context, stored);
    }
    return stored;
  }
}
