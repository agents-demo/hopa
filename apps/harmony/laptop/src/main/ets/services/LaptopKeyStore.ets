import asset from '@ohos.security.asset';
import { buffer, util } from '@kit.ArkTS';

/**
 * The laptop's own model key, in Asset Store.
 *
 * A laptop install never borrows the phone's key: the two machines are
 * independent, and a key that leaves one device is a key that has leaked.
 */
export class LaptopKeyStore {
  private static readonly ALIAS: string = 'hopa_laptop_key';

  private static aliasBytes(): Uint8Array {
    return new util.TextEncoder().encodeInto(LaptopKeyStore.ALIAS);
  }

  private static query(): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, LaptopKeyStore.aliasBytes());
    return query;
  }

  static async save(key: string): Promise<boolean> {
    if (key.trim().length < 8) {
      return false;
    }
    const attrs: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attrs.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(key.trim()));
    attrs.set(asset.Tag.ALIAS, LaptopKeyStore.aliasBytes());
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      try {
        await asset.remove(LaptopKeyStore.query());
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
    const query: asset.AssetMap = LaptopKeyStore.query();
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
      await asset.remove(LaptopKeyStore.query());
    } catch (error) {
      // Nothing stored.
    }
  }
}
