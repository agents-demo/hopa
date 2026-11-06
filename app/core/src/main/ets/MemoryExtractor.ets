/**
 * Extracts an explicit memory from a user message.
 *
 * Only explicit requests are stored: "remember that ...", "remember ...",
 * "please remember ...", and the equivalent Chinese phrases. Anything else is
 * ignored, so the agent never silently records personal data.
 */
export class MemoryExtractor {
  private static readonly PREFIXES: string[] = [
    'please remember that ',
    'please remember ',
    'remember that ',
    'remember ',
    '请记住',
    '记住'
  ];

  static extract(text: string): string | undefined {
    const trimmed: string = text.trim();
    const lower: string = trimmed.toLowerCase();
    for (const prefix of MemoryExtractor.PREFIXES) {
      if (lower.startsWith(prefix.toLowerCase())) {
        const value: string = trimmed.substring(prefix.length).trim();
        return value.length > 0 ? value : undefined;
      }
    }
    return undefined;
  }
}
