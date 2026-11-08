/**
 * The one catalogue of secondary destinations.
 *
 * The bottom bar keeps four primary slots. New screens are added here,
 * grouped and searchable, so the shell never grows with the product.
 */
export class ToolEntry {
  title: string = '';
  subtitle: string = '';
  key: string = '';

  constructor(title: string, subtitle: string, key: string) {
    this.title = title;
    this.subtitle = subtitle;
    this.key = key;
  }
}

export class ToolGroup {
  title: string = '';
  entries: ToolEntry[] = [];
}

function group(title: string, entries: ToolEntry[]): ToolGroup {
  const result = new ToolGroup();
  result.title = title;
  result.entries = entries;
  return result;
}

const CATALOG: ToolGroup[] = [
  group('Agent', [
    new ToolEntry('Plans', 'Scheduled runs while HOPA is open', 'plans'),
    new ToolEntry('Runs and batches', 'Past runs and a batch of goals', 'runs'),
    new ToolEntry('Memory', 'Facts HOPA remembers about you', 'memory')
  ]),
  group('Surfaces', [
    new ToolEntry('Browser', 'Read, click and type on a web page', 'browser'),
    new ToolEntry('Apps', 'Open an installed app by name', 'apps'),
    new ToolEntry('Screens', 'Live phone screen and tap targets', 'screens')
  ]),
  group('Model and usage', [
    new ToolEntry('Models', 'Provider, endpoint, model and key', 'models'),
    new ToolEntry('Usage', 'Tokens and time spent', 'usage')
  ]),
  group('Phone', [
    new ToolEntry('Phone setup', 'Accessibility and the PC bridge', 'phone'),
    new ToolEntry('Self-check', 'What works on this phone', 'selfcheck'),
    new ToolEntry('MCP servers', 'What runs on the phone and the PC', 'mcpservers')
  ]),
  group('Data', [
    new ToolEntry('Files', 'Exported data on this device', 'files'),
    new ToolEntry('Source', 'Model, backend and observation source', 'source')
  ]),
  group('App', [
    new ToolEntry('Welcome', 'The first-run tour', 'welcome'),
    new ToolEntry('About', 'Version and project links', 'about'),
    new ToolEntry('License', 'Apache-2.0 and third-party notices', 'license')
  ])
];

/** Groups whose title or entries match the search text. */
export function toolGroups(query: string): ToolGroup[] {
  const needle: string = query.trim().toLowerCase();
  const result: ToolGroup[] = [];
  for (const source of CATALOG) {
    const entries: ToolEntry[] = [];
    for (const entry of source.entries) {
      if (needle.length === 0 ||
        entry.title.toLowerCase().indexOf(needle) >= 0 ||
        entry.subtitle.toLowerCase().indexOf(needle) >= 0) {
        entries.push(entry);
      }
    }
    if (entries.length > 0) {
      result.push(group(source.title, entries));
    }
  }
  return result;
}
