import { APP_CATALOG, SITE_CATALOG } from './AppCatalog';

/**
 * The catalogue block for the model: what each app is for and how to start it,
 * plus the sites that can be opened in the built-in browser.
 */
export class AppCatalogPrompt {
  static text(): string {
    const lines: string[] = ['APPS:'];
    for (const app of APP_CATALOG) {
      if (app.bundle.length > 0) {
        let line: string = `${app.display}: ${app.bundle}`;
        if (app.purpose.length > 0) {
          line += ` - ${app.purpose}`;
        }
        if (app.actions.length > 0) {
          line += ` | ${app.actions.join('; ')}`;
        }
        lines.push(line);
      } else if (app.purpose.length > 0) {
        lines.push(`${app.display}: no verified bundle - ${app.purpose}`);
      }
    }
    lines.push('');
    lines.push('SITES (https only; open with web.navigate when network is on):');
    for (const site of SITE_CATALOG) {
      if (site.domains.length > 0) {
        lines.push(`${site.display}: ${site.domains[0]}`);
      }
    }
    return lines.join('\n');
  }
}
