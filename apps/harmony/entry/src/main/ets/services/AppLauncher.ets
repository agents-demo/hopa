import { common } from '@kit.AbilityKit';
import { UiLauncher } from '@hopa/capability-a11y';
import { APP_CATALOG, CatalogApp } from './AppCatalog';

/**
 * Starts another app from the entry module's UI context.
 *
 * HarmonyOS needs an ability name. The model supplies only the bundle, so the
 * launcher tries the common launcher-ability names; the App catalogue stores
 * the verified ability for the apps HOPA knows.
 */
export class AppLauncher implements UiLauncher {
  /** Android bundles the model may guess instead of the HarmonyOS ones. */
  private static readonly ALIASES: Map<string, string> = new Map<string, string>([
    ['com.android.settings', 'com.huawei.hmos.settings'],
    ['com.android.chrome', 'com.huawei.hmos.browser'],
    ['com.android.camera', 'com.huawei.hmos.camera'],
    ['com.android.gallery3d', 'com.huawei.hmos.photos'],
    ['com.google.android.apps.photos', 'com.huawei.hmos.photos'],
    ['com.android.deskclock', 'com.huawei.hmos.clock'],
    ['com.android.calendar', 'com.huawei.hmos.calendar'],
    ['com.android.calculator2', 'com.huawei.hmos.calculator'],
    ['com.android.dialer', 'com.huawei.hmos.contacts'],
    ['com.android.contacts', 'com.huawei.hmos.contacts'],
    ['com.android.mms', 'com.huawei.hmos.mms'],
    ['com.android.documentsui', 'com.huawei.hmos.files']
  ]);

  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async launch(bundle: string, ability: string): Promise<boolean> {
    let target: string = bundle;
    for (const app of APP_CATALOG) {
      if (app.bundle === target) {
        break;
      }
      if (app.aliases.includes(target)) {
        target = app.bundle;
        break;
      }
    }
    const alias: string | undefined = AppLauncher.ALIASES.get(target);
    if (alias !== undefined) {
      target = alias;
    }
    let known: string = ability;
    if (known.length === 0) {
      for (const app of APP_CATALOG) {
        if (app.bundle === target && app.ability.length > 0) {
          known = app.ability;
          break;
        }
      }
    }
    const candidates: string[] = known.length > 0
      ? [known]
      : [
        'EntryAbility',
        'MainAbility',
        `${target}.EntryAbility`,
        `${target}.MainAbility`
      ];
    for (const name of candidates) {
      try {
        await this.context.startAbility({ bundleName: target, abilityName: name });
        return true;
      } catch (error) {
        // Try the next candidate.
      }
    }
    try {
      await this.context.startAbility({ bundleName: target });
      return true;
    } catch (error) {
      return false;
    }
  }
}
