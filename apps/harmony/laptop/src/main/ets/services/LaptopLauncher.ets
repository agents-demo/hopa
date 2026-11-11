import { bundleManager, common, Want } from '@kit.AbilityKit';
import { APP_CATALOG, CatalogApp } from '@hopa/app';

/**
 * Opening an app on this laptop.
 *
 * A normal app cannot enumerate the launcher, so the launchpad is the catalog
 * HOPA already knows, narrowed to what is actually installed here. Launching
 * goes through a Want, which works while HOPA is in the foreground — no bridge,
 * no permission.
 */
export class LaptopApp {
  bundle: string = '';
  label: string = '';
  installed: boolean = false;
}

export class LaptopLauncher {
  private context: common.UIAbilityContext | undefined = undefined;
  private installedCache: Map<string, boolean> = new Map<string, boolean>();
  /**
   * The catalog is shared with the phone, so it names the phone's bundles.
   * A few apps ship under a different name on the 2-in-1; the launcher is the
   * only place that knows the difference.
   */
  private static readonly DEVICE_ALIASES: Record<string, string> = {
    'com.ss.hm.ugc.aweme': 'com.ss.ohpc.ugc.aweme'
  };

  /** The bundle this machine would install for a catalog bundle. */
  private bundlesFor(bundle: string): string[] {
    const alias: string = LaptopLauncher.DEVICE_ALIASES[bundle] ?? '';
    return alias.length > 0 ? [bundle, alias] : [bundle];
  }

  attach(context: common.UIAbilityContext): void {
    this.context = context;
  }

  private knowable(): CatalogApp[] {
    const known: CatalogApp[] = [];
    for (const app of APP_CATALOG) {
      if (app.bundle.length > 0) {
        known.push(app);
      }
    }
    return known;
  }

  isInstalled(bundle: string): boolean {
    // A promise API cannot be called synchronously here; cache the answer once.
    return this.installedCache.get(bundle) ?? false;
  }

  /** Ask the system which catalog apps exist, once, and remember it. */
  async loadInstalled(): Promise<void> {
    for (const entry of this.knowable()) {
      let present: boolean = false;
      for (const bundle of this.bundlesFor(entry.bundle)) {
        try {
          await bundleManager.getBundleInfo(bundle, 0);
          present = true;
          break;
        } catch (error) {
          // Try the next name this device might use.
        }
      }
      this.installedCache.set(entry.bundle, present);
    }
  }

  /** The catalog as this machine sees it: installed first, then the rest. */
  apps(): LaptopApp[] {
    const installed: LaptopApp[] = [];
    const missing: LaptopApp[] = [];
    for (const entry of this.knowable()) {
      const app = new LaptopApp();
      app.bundle = entry.bundle;
      app.label = entry.display;
      app.installed = this.isInstalled(entry.bundle);
      if (app.installed) {
        installed.push(app);
      } else {
        missing.push(app);
      }
    }
    installed.sort((a: LaptopApp, b: LaptopApp) => a.label.localeCompare(b.label));
    return installed;
  }

  async launch(bundle: string): Promise<boolean> {
    const context = this.context;
    if (context === undefined || bundle.length === 0) {
      return false;
    }
    for (const name of this.bundlesFor(bundle)) {
      try {
        const want: Want = bundleManager.getLaunchWantForBundleSync(name);
        await context.startAbility(want);
        return true;
      } catch (error) {
        // The resolver does not answer for every system app on this build
        // (Settings and Browser are the known ones). The explicit ability is
        // still a plain Want, so fall back to the names HarmonyOS ships.
      }
      const abilities: string[] = [
        `${name}.MainAbility`,
        `${name}.EntryAbility`,
        'EntryAbility',
        'MainAbility'
      ];
      for (const ability of abilities) {
        try {
          const want: Want = { bundleName: name, abilityName: ability };
          await context.startAbility(want);
          return true;
        } catch (error) {
          // Try the next ability name.
        }
      }
    }
    return false;
  }
}
