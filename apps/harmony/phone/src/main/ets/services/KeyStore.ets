import asset from '@ohos.security.asset';
import { buffer, util } from '@kit.ArkTS';

/**
 * Secrets in HarmonyOS Asset Store (not in the HAP, not in preferences).
 *
 * Two entries: the model key and the bridge session. If the store is
 * unavailable, handling falls back to memory only, so nothing is ever written
 * in clear text.
 */
export class KeyStore {
  private static readonly ALIAS: string = 'hopa_model_key';
  private static readonly SESSION_ALIAS: string = 'hopa_bridge_session';

  private static aliasBytes(alias: string): Uint8Array {
    return new util.TextEncoder().encodeInto(alias);
  }

  private static queryFor(alias: string): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, KeyStore.aliasBytes(alias));
    return query;
  }

  private static query(): asset.AssetMap {
    return KeyStore.queryFor(KeyStore.ALIAS);
  }

  private static async saveSecret(alias: string, secret: string, minLength: number): Promise<boolean> {
    if (secret.trim().length < minLength) {
      return false;
    }
    const attrs: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attrs.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(secret.trim()));
    attrs.set(asset.Tag.ALIAS, KeyStore.aliasBytes(alias));
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      try {
        await asset.remove(KeyStore.queryFor(alias));
      } catch (error) {
        // No previous entry.
      }
      await asset.add(attrs);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static async loadSecret(alias: string): Promise<string> {
    const query: asset.AssetMap = KeyStore.queryFor(alias);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const rows: Array<asset.AssetMap> = await asset.query(query);
      if (rows.length === 0) {
        return '';
      }
      const secret: asset.Value | undefined = rows[0].get(asset.Tag.SECRET);
      if (secret instanceof Uint8Array) {
        return buffer.from(secret.buffer).toString('utf8');
      }
      return '';
    } catch (error) {
      return '';
    }
  }

  private static async clearSecret(alias: string): Promise<void> {
    try {
      await asset.remove(KeyStore.queryFor(alias));
    } catch (error) {
      // Nothing stored.
    }
  }

  static async save(key: string): Promise<boolean> {
    return KeyStore.saveSecret(KeyStore.ALIAS, key, 8);
  }

  static async load(): Promise<string> {
    return KeyStore.loadSecret(KeyStore.ALIAS);
  }

  static async clear(): Promise<void> {
    await KeyStore.clearSecret(KeyStore.ALIAS);
  }

  /** The bridge session is JSON: access token plus its refresh token. */
  static async saveBridgeSession(session: string): Promise<boolean> {
    return KeyStore.saveSecret(KeyStore.SESSION_ALIAS, session, 10);
  }

  static async loadBridgeSession(): Promise<string> {
    return KeyStore.loadSecret(KeyStore.SESSION_ALIAS);
  }

  static async clearBridgeSession(): Promise<void> {
    await KeyStore.clearSecret(KeyStore.SESSION_ALIAS);
  }
}
