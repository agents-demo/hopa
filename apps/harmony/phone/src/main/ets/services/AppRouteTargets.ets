import { RouteTarget } from '@hopa/core';
import { APP_CATALOG, SITE_CATALOG } from './AppCatalog';

/** Turns the generated catalogue into routing targets. One adapter, no policy. */
export class AppRouteTargets {
  static all(): RouteTarget[] {    const targets: RouteTarget[] = [];
    for (const app of APP_CATALOG) {
      const target = new RouteTarget();
      target.name = app.name;
      target.display = app.display;
      target.kind = 'app';
      target.bundle = app.bundle;
      target.aliases = app.aliases;
      target.purpose = app.purpose;
      target.actions = app.actions;
      targets.push(target);
    }
    for (const site of SITE_CATALOG) {
      const target = new RouteTarget();
      target.name = site.name;
      target.display = site.display;
      target.kind = 'site';
      target.domains = site.domains;
      target.aliases = site.aliases;
      target.purpose = site.purpose;
      targets.push(target);
    }
    return targets;
  }

  /** Bundle name -> human display name, for the chat narrator. */
  static displayNames(): Map<string, string> {
    const names = new Map<string, string>();
    for (const app of APP_CATALOG) {
      if (app.bundle.length > 0) {
        names.set(app.bundle.toLowerCase(), app.display);
      }
    }
    return names;
  }
}
