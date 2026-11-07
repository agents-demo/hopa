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

/** Turns the model's reply into one Action, or undefined for plain text. */
export class ActionParser {
  static parse(text: string): Action | undefined {
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
}
