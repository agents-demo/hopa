import { Action } from '../Types';

class ActionPayload {
  kind: string = '';
  target: string = '';
  text: string = '';
  url: string = '';
  app: string = '';
  x: number = 0;
  y: number = 0;
  toX: number = 0;
  toY: number = 0;
}

const KNOWN_KINDS: string[] = [
  'web.navigate',
  'web.read',
  'web.click',
  'web.type',
  'ui.launch',
  'ui.tap',
  'ui.doubleTap',
  'ui.type',
  'ui.swipe',
  'ui.longPress',
  'ui.back',
  'ui.home',
  'ui.scroll',
  'a11y.observe',
  'sandbox.run',
  'sandbox.runNetworked',
  'system.setAlarm',
  'system.addEvent',
  'system.openLink'
];

/** Turns the model's reply into one Action, or undefined for plain text. */
export class ActionParser {
  static parse(text: string): Action | undefined {
    const direct: Action | undefined = ActionParser.fromJson(text);
    if (direct !== undefined) {
      return direct;
    }
    // Models sometimes explain first and put the action after the prose.
    // Only a JSON object with a known kind counts, so an answer that happens
    // to mention JSON is still treated as text.
    const objects: string[] = ActionParser.embeddedObjects(text);
    for (let i = objects.length - 1; i >= 0; i--) {
      const action: Action | undefined = ActionParser.fromJson(objects[i]);
      if (action !== undefined) {
        return action;
      }
    }
    return undefined;
  }

  /** Parses one JSON object, optionally wrapped in a Markdown code fence. */
  private static fromJson(text: string): Action | undefined {
    try {
      let raw: string = text.trim();
      if (raw.startsWith('```')) {
        raw = raw.replace(/^```[a-zA-Z]*\s*/, '').replace(/```\s*$/, '').trim();
      }
      const payload = JSON.parse(raw) as ActionPayload;
      if (payload.kind === undefined || payload.kind.length === 0) {
        return undefined;
      }
      if (payload.kind === 'finish' || payload.kind === 'done') {
        return undefined;
      }
      if (KNOWN_KINDS.indexOf(payload.kind) < 0) {
        return undefined;
      }
      const action = new Action(payload.kind);
      action.target = payload.target === undefined ? '' : payload.target;
      action.text = payload.text === undefined ? '' : payload.text;
      action.url = payload.url === undefined ? '' : payload.url;
      action.app = payload.app === undefined ? '' : payload.app;
      action.x = payload.x === undefined ? 0 : payload.x;
      action.y = payload.y === undefined ? 0 : payload.y;
      action.toX = payload.toX === undefined ? 0 : payload.toX;
      action.toY = payload.toY === undefined ? 0 : payload.toY;
      // isPayment is never read from the model. The gate classifies it.
      return action;
    } catch (error) {
      return undefined;
    }
  }

  /** Every balanced `{...}` block that starts at the top level of the text. */
  private static embeddedObjects(text: string): string[] {
    const found: string[] = [];
    let depth: number = 0;
    let start: number = -1;
    let inString: boolean = false;
    let escaped: boolean = false;
    for (let i = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === '\\') {
          escaped = true;
        } else if (ch === '"') {
          inString = false;
        }
        continue;
      }
      if (ch === '"') {
        inString = true;
      } else if (ch === '{') {
        if (depth === 0) {
          start = i;
        }
        depth += 1;
      } else if (ch === '}' && depth > 0) {
        depth -= 1;
        if (depth === 0 && start >= 0) {
          found.push(text.substring(start, i + 1));
          start = -1;
        }
      }
    }
    return found;
  }
}
