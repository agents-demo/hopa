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
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async launch(bundle: string, ability: string): Promise<boolean> {
    let known: string = ability;
    if (known.length === 0) {
      for (const app of APP_CATALOG) {
        if (app.bundle === bundle && app.ability.length > 0) {
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
        `${bundle}.EntryAbility`,
        `${bundle}.MainAbility`
      ];
    for (const name of candidates) {
      try {
        await this.context.startAbility({ bundleName: bundle, abilityName: name });
        return true;
      } catch (error) {
        // Try the next candidate.
      }
    }
    try {
      await this.context.startAbility({ bundleName: bundle });
      return true;
    } catch (error) {
      return false;
    }
  }
}
