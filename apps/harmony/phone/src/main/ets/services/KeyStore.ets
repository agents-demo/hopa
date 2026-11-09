import asset from '@ohos.security.asset';
import { buffer, util } from '@kit.ArkTS';

/**
 * The model key, stored in HarmonyOS Asset Store (not in the HAP, not in
 * preferences). If the store is unavailable, key handling falls back to memory
 * only, so the secret is never written in clear text.
 */
export class KeyStore {
  private static readonly ALIAS: string = 'hopa_model_key';

  private static aliasBytes(): Uint8Array {
    return new util.TextEncoder().encodeInto(KeyStore.ALIAS);
  }

  private static query(): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, KeyStore.aliasBytes());
    return query;
  }

  static async save(key: string): Promise<boolean> {
    if (key.trim().length < 8) {
      return false;
    }
    const attrs: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attrs.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(key.trim()));
    attrs.set(asset.Tag.ALIAS, KeyStore.aliasBytes());
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      try {
        await asset.remove(KeyStore.query());
      } catch (error) {
        // No previous entry.
      }
      await asset.add(attrs);
      return true;
    } catch (error) {
      return false;
    }
  }

  static async load(): Promise<string> {
    const query: asset.AssetMap = KeyStore.query();
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

  static async clear(): Promise<void> {
    try {
      await asset.remove(KeyStore.query());
    } catch (error) {
      // Nothing stored.
    }
  }
}
