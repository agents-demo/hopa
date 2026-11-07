import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** Non-secret settings. The API key is deliberately not stored here. */
export class StoredSettings {
  provider: string = 'openai';
  endpoint: string = 'https://api.openai.com/v1';
  model: string = 'gpt-4o-mini';
  network: boolean = false;
  autonomous: boolean = false;
  bridgeUrl: string = '';
  bridgeToken: string = '';
}

/**
 * Persists endpoint, model, provider and the network toggle.
 *
 * The API key is **not** persisted: there is no secure-storage implementation
 * yet, and writing a key in plain preferences would be worse than asking for it
 * again after a restart.
 */
export class SettingsStore {
  private static readonly NAME: string = 'hopa_settings';

  static async load(context: Context): Promise<StoredSettings> {
    const settings = new StoredSettings();
    const store = await preferences.getPreferences(context, SettingsStore.NAME);
    const provider = await store.get('provider', settings.provider);
    if (typeof provider === 'string') {
      settings.provider = provider;
    }
    const endpoint = await store.get('endpoint', settings.endpoint);
    if (typeof endpoint === 'string') {
      settings.endpoint = endpoint;
    }
    const model = await store.get('model', settings.model);
    if (typeof model === 'string') {
      settings.model = model;
    }
    const network = await store.get('network', settings.network);
    if (typeof network === 'boolean') {
      settings.network = network;
    }
    const autonomous = await store.get('autonomous', settings.autonomous);
    if (typeof autonomous === 'boolean') {
      settings.autonomous = autonomous;
    }
    const bridgeUrl = await store.get('bridge_url', settings.bridgeUrl);
    if (typeof bridgeUrl === 'string') {
      settings.bridgeUrl = bridgeUrl;
    }
    const bridgeToken = await store.get('bridge_token', settings.bridgeToken);
    if (typeof bridgeToken === 'string') {
      settings.bridgeToken = bridgeToken;
    }
    return settings;
  }

  static async save(context: Context, settings: StoredSettings): Promise<void> {
    const store = await preferences.getPreferences(context, SettingsStore.NAME);
    await store.put('provider', settings.provider);
    await store.put('endpoint', settings.endpoint);
    await store.put('model', settings.model);
    await store.put('network', settings.network);
    await store.put('autonomous', settings.autonomous);
    await store.put('bridge_url', settings.bridgeUrl);
    await store.put('bridge_token', settings.bridgeToken);
    await store.flush();
  }

  /** True until the user has seen the Welcome page once. */
  static async needsWelcome(context: Context): Promise<boolean> {
    const store = await preferences.getPreferences(context, SettingsStore.NAME);
    const seen = await store.get('welcome_seen', false);
    return typeof seen === 'boolean' ? !seen : true;
  }

  static async markWelcomeSeen(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, SettingsStore.NAME);
    await store.put('welcome_seen', true);
    await store.flush();
  }
}
