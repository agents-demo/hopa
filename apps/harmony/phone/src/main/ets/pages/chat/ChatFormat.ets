/**
 * Parsing/formatting for stored chat messages.
 *
 * Kept free of UI state so the chat page, recap card and future laptop shell
 * can share exactly one interpretation of a message.
 */
export class ChatFormat {
  static isUser(item: ResourceStr): boolean {
    return typeof item === 'string' && item.startsWith('You: ');
  }

  static isHopa(item: ResourceStr): boolean {
    return typeof item === 'string' && item.startsWith('HOPA: ');
  }

  /** One marker line at the top of a stored answer: steps and screenshot. */
  static metaLine(item: ResourceStr): string {
    if (typeof item !== 'string') {
      return '';
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6meta\u27e7') !== 0) {
      return '';
    }
    const end: number = body.indexOf('\n');
    return end < 0 ? body : body.substring(0, end);
  }

  static metaValue(item: ResourceStr, key: string): string {
    const line: string = ChatFormat.metaLine(item);
    if (line.length === 0) {
      return '';
    }
    for (const part of line.substring('\u27e6meta\u27e7'.length).split(';')) {
      if (part.startsWith(`${key}=`)) {
        return part.substring(key.length + 1);
      }
    }
    return '';
  }

  static stepsOf(item: ResourceStr): string[] {
    const list: string = ChatFormat.metaValue(item, 'steps');
    return list.length === 0 ? [] : list.split(' | ');
  }

  static shotOf(item: ResourceStr): string {
    return ChatFormat.metaValue(item, 'shot');
  }

  static textOf(item: ResourceStr): string {
    const text: ResourceStr = ChatFormat.bubbleText(item);
    return typeof text === 'string' ? text : '';
  }

  static bubbleText(item: ResourceStr): ResourceStr {
    if (typeof item !== 'string') {
      return item;
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6meta\u27e7') === 0) {
      const end: number = body.indexOf('\n');
      return end < 0 ? '' : body.substring(end + 1);
    }
    if (item.startsWith('You: ')) {
      return item.substring(5);
    }
    if (item.startsWith('HOPA: ')) {
      return ChatFormat.plainAnswer(item.substring(6));
    }
    return item;
  }

  /** Numbered items of an answer; empty when the text is prose. */
  static listItems(text: string): string[] {
    const items: string[] = [];
    for (const line of text.split('\n')) {
      const match = line.trim().match(/^\d+[.)]\s+(.*)$/);
      if (match !== null) {
        items.push(match[1]);
      }
    }
    return items.length >= 2 ? items : [];
  }

  /** A short sentence that introduces the list, when the model wrote one. */
  static listLead(text: string): string {
    for (const line of text.split('\n')) {
      const trimmed: string = line.trim();
      if (trimmed.length === 0) {
        continue;
      }
      if (trimmed.match(/^\d+[.)]\s+/) !== null) {
        return '';
      }
      return trimmed;
    }
    return '';
  }

  /** Hide raw tool-call markup a model may leak into its answer. */
  static stripToolMarkup(text: string): string {
    const kept: string[] = [];
    for (const line of text.split('\n')) {
      if (/DSML|<\/?parameter|<\/?invoke|string="true"/i.test(line)) {
        continue;
      }
      kept.push(line);
    }
    let clean: string = kept.join('\n');
    clean = clean.replace(/<\|\s*[\s\S]*?\s*\|>/g, '');
    clean = clean.replace(/<\/?\s*parameter[^>]*>/gi, '');
    clean = clean.replace(/<\/?\s*invoke[^>]*>/gi, '');
    return clean;
  }

  /** Chat bubbles are plain text; strip the Markdown a model may add. */
  static plainAnswer(text: string): string {
    let clean: string = ChatFormat.stripToolMarkup(text);
    clean = clean.replace(/\*\*/g, '');
    clean = clean.replace(/__/g, '');
    clean = clean.replace(/`/g, '');
    clean = clean.replace(/^#{1,6}\s*/gm, '');
    clean = clean.replace(/^>\s?/gm, '');
    clean = clean.replace(/\\n/g, '\n');
    const kept: string[] = [];
    for (const raw of clean.split('\n')) {
      kept.push(raw.length > 220 ? `${raw.substring(0, 220)}\u2026` : raw);
    }
    clean = kept.join('\n');
    if (clean.trim().length === 0) {
      return 'I hit a formatting error. Please try again.';
    }
    return clean.trim();
  }
}
