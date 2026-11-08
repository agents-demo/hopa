const TITLES: Map<string, string> = new Map<string, string>([
  ['chat', 'Chat'],
  ['activity', 'Activity'],
  ['capabilities', 'Capabilities'],
  ['plans', 'Plans'],
  ['memory', 'Memory'],
  ['browser', 'Browser'],
  ['screens', 'Screens'],
  ['settings', 'Settings'],
  ['about', 'About'],
  ['run', 'Run'],
  ['selfcheck', 'Self-check'],
  ['files', 'Files'],
  ['license', 'License'],
  ['welcome', 'Welcome'],
  ['apps', 'Apps'],
  ['runs', 'Runs and batches'],
  ['models', 'Models'],
  ['usage', 'Usage'],
  ['phone', 'Phone setup'],
  ['source', 'Source'],
  ['mcpservers', 'MCP servers']
]);

/** The header title for a page key. */
export function pageTitle(key: string): string {
  const title: string | undefined = TITLES.get(key);
  return title === undefined ? 'HOPA' : title;
}
