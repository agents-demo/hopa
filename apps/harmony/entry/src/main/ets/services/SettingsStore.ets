import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** Non-secret settings. The API key is deliberately not stored here. */
export class StoredSettings {
  provider: string = 'openai';
  endpoint: string = 'https://api.openai.com/v1';
  model: string = 'gpt-4o-mini';
  network: boolean = false;
  autonomous: boolean = false;
  appearance: string = 'system';
  profile: string = 'everyday';
  style: string = 'calm';
  showSteps: boolean = true;
  reduceMotion: boolean = false;
  speakReplies: boolean = false;
  bridgeUrl: string = '';
  bridgeToken: string = '';
  lastTokens: number = 0;
  lastDurationMs: number = 0;
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
    const appearance = await store.get('appearance', settings.appearance);
    if (typeof appearance === 'string') {
      settings.appearance = appearance;
    }
    const profile = await store.get('profile', settings.profile);
    if (typeof profile === 'string') {
      settings.profile = profile;
    }
    const style = await store.get('style', settings.style);
    if (typeof style === 'string') {
      settings.style = style;
    }
    const showSteps = await store.get('show_steps', settings.showSteps);
    if (typeof showSteps === 'boolean') {
      settings.showSteps = showSteps;
    }
    const reduceMotion = await store.get('reduce_motion', settings.reduceMotion);
    if (typeof reduceMotion === 'boolean') {
      settings.reduceMotion = reduceMotion;
    }
    const speakReplies = await store.get('speak_replies', settings.speakReplies);
    if (typeof speakReplies === 'boolean') {
      settings.speakReplies = speakReplies;
    }
    const bridgeUrl = await store.get('bridge_url', settings.bridgeUrl);
    if (typeof bridgeUrl === 'string') {
      settings.bridgeUrl = bridgeUrl;
    }
    const bridgeToken = await store.get('bridge_token', settings.bridgeToken);
    if (typeof bridgeToken === 'string') {
      settings.bridgeToken = bridgeToken;
    }
    const lastTokens = await store.get('last_tokens', settings.lastTokens);
    if (typeof lastTokens === 'number') {
      settings.lastTokens = lastTokens;
    }
    const lastDurationMs = await store.get('last_duration_ms', settings.lastDurationMs);
    if (typeof lastDurationMs === 'number') {
      settings.lastDurationMs = lastDurationMs;
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
    await store.put('appearance', settings.appearance);
    await store.put('profile', settings.profile);
    await store.put('style', settings.style);
    await store.put('show_steps', settings.showSteps);
    await store.put('reduce_motion', settings.reduceMotion);
    await store.put('speak_replies', settings.speakReplies);
    await store.put('bridge_url', settings.bridgeUrl);
    await store.put('bridge_token', settings.bridgeToken);
    await store.put('last_tokens', settings.lastTokens);
    await store.put('last_duration_ms', settings.lastDurationMs);
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
