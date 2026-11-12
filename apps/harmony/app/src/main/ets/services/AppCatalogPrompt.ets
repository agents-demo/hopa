import { APP_CATALOG } from './AppCatalog';

/**
 * The catalogue block for the model: what each app is for and how to start it.
 *
 * There is deliberately no "open the website instead" route: the runtimes have
 * no web capability, so naming one only made the model stop at
 * "no capability for web.navigate" while the app was right there.
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
    lines.push('Open an app with ui.launch and the bundle above. There is no web capability: when a site is wanted, open its app.');
    return lines.join('\n');
  }
}
