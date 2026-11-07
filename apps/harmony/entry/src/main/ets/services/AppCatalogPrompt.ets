import { APP_CATALOG } from './AppCatalog';

/** The confirmed bundle/name pairs, as one prompt block. */
export class AppCatalogPrompt {
  static text(): string {
    const lines: string[] = [];
    for (const app of APP_CATALOG) {
      if (app.confirmed && app.bundle.length > 0) {
        lines.push(`${app.display}: ${app.bundle}`);
      }
    }
    return lines.join('\n');
  }
}
