import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/**
 * Bundles the user chose to trust for outgoing messages.
 *
 * The list is per app, survives a restart, and is never consulted for a
 * payment or a destructive action.
 */
export class TrustedApps {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'trusted_apps';
  private static bundles: Set<string> = new Set<string>();

  static async load(context: Context): Promise<string[]> {
    try {
      const store = await preferences.getPreferences(context, TrustedApps.STORE);
      const raw = await store.get(TrustedApps.KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        for (const part of raw.split(',')) {
          const key: string = part.trim().toLowerCase();
          if (key.length > 0) {
            TrustedApps.bundles.add(key);
          }
        }
      }
    } catch (error) {
      TrustedApps.bundles.clear();
    }
    return TrustedApps.all();
  }

  static all(): string[] {
    const list: string[] = [];
    TrustedApps.bundles.forEach((bundle: string) => {
      list.push(bundle);
    });
    return list;
  }

  static has(bundle: string): boolean {
    return TrustedApps.bundles.has(bundle.trim().toLowerCase());
  }

  static add(context: Context, bundle: string): void {
    const key: string = bundle.trim().toLowerCase();
    if (key.length === 0) {
      return;
    }
    TrustedApps.bundles.add(key);
    TrustedApps.save(context);
  }

  static remove(context: Context, bundle: string): void {
    TrustedApps.bundles.delete(bundle.trim().toLowerCase());
    TrustedApps.save(context);
  }

  private static save(context: Context): void {
    let text: string = '';
    TrustedApps.bundles.forEach((bundle: string) => {
      text = text.length === 0 ? bundle : `${text},${bundle}`;
    });
    preferences.getPreferences(context, TrustedApps.STORE)
      .then((store: preferences.Preferences) => {
        store.put(TrustedApps.KEY, text).then(() => {
          store.flush();
        });
      })
      .catch(() => {
        // Best effort: the in-memory list still applies this session.
      });
  }
}
