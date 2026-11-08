import { Action } from '../Types';
import { Screen, ScreenNode } from '../domain/Screen';

/**
 * Turns a gated action into a sentence a person understands.
 *
 * The approval sheet used to show the raw action kind and a ref (`ui.type`,
 * `e8`). This class uses the visible label of the target instead. It is display
 * text only; the gate still decides from the action and the screen.
 */
export class ApprovalDescription {
  static title(action: Action, screen: Screen | undefined, names: Map<string, string>): string {
    const kind: string = action.kind;
    if (kind === 'ui.launch') {
      return `Open ${ApprovalDescription.appName(action.app, names)}?`;
    }
    if (kind === 'ui.tap' || kind === 'ui.doubleTap' || kind === 'ui.longPress') {
      const label: string = ApprovalDescription.label(action, screen);
      const lower: string = label.toLowerCase();
      if (lower === 'send') {
        return 'Send this message?';
      }
      if (lower === 'post') {
        return 'Post this?';
      }
      if (lower === 'delete') {
        return 'Delete this?';
      }
      return `Tap “${label}”?`;
    }
    if (kind === 'ui.type') {
      return `Type into “${ApprovalDescription.label(action, screen)}”?`;
    }
    if (kind === 'ui.swipe' || kind === 'ui.scroll') {
      return 'Scroll the screen?';
    }
    if (kind === 'ui.back') {
      return 'Go back?';
    }
    if (kind === 'ui.home') {
      return 'Go to the home screen?';
    }
    if (kind === 'web.navigate') {
      return 'Open this page?';
    }
    if (kind === 'web.click') {
      return `Click “${action.target}”?`;
    }
    if (kind === 'web.type') {
      return `Type into “${action.target}”?`;
    }
    if (kind === 'ui.sendMessage') {
      return 'Send this message?';
    }
    if (kind === 'system.setAlarm') {
      return 'Set an alarm?';
    }
    if (kind === 'system.addEvent') {
      return 'Add a calendar event?';
    }
    if (kind === 'system.openLink') {
      return 'Open this link?';
    }
    if (kind === 'system.delete') {
      return 'Delete this?';
    }
    if (kind === 'system.uninstall') {
      return 'Uninstall this app?';
    }
    if (kind === 'system.call') {
      return 'Make a call?';
    }
    if (kind === 'sandbox.run') {
      return 'Run this script?';
    }
    return 'Allow this action?';
  }

  static body(action: Action, screen: Screen | undefined, names: Map<string, string>): string {
    const kind: string = action.kind;
    if (kind === 'ui.launch') {
      return `HOPA will open ${ApprovalDescription.appName(action.app, names)}. Allow it?`;
    }
    if (kind === 'ui.tap' || kind === 'ui.doubleTap' || kind === 'ui.longPress') {
      return `HOPA will tap “${ApprovalDescription.label(action, screen)}” on the screen. Allow it?`;
    }
    if (kind === 'ui.type') {
      const text: string = ApprovalDescription.shorten(action.text);
      return text.length > 0
        ? `HOPA will type:\n\n“${text}”\n\nAllow it?`
        : 'HOPA will type into the field. Allow it?';
    }
    if (kind === 'ui.swipe' || kind === 'ui.scroll') {
      return 'HOPA will scroll the current screen. Allow it?';
    }
    if (kind === 'ui.back') {
      return 'HOPA will go back. Allow it?';
    }
    if (kind === 'ui.home') {
      return 'HOPA will go to the home screen. Allow it?';
    }
    if (kind === 'web.navigate') {
      return `HOPA will open:\n\n${action.url}\n\nAllow it?`;
    }
    if (kind === 'web.click') {
      return `HOPA will click “${action.target}” on the page. Allow it?`;
    }
    if (kind === 'web.type') {
      const text: string = ApprovalDescription.shorten(action.text);
      return text.length > 0
        ? `HOPA will type into “${action.target}”:\n\n“${text}”\n\nAllow it?`
        : `HOPA will type into “${action.target}”. Allow it?`;
    }
    if (kind === 'ui.sendMessage') {
      const text: string = ApprovalDescription.shorten(action.text);
      const target: string = ApprovalDescription.messageTarget(action, screen);
      return text.length > 0
        ? `To: ${target}\n\n“${text}”\n\nNothing is sent until you choose.`
        : `HOPA will send a message to ${target}. Allow it?`;
    }
    if (kind === 'system.setAlarm') {
      return 'HOPA will set an alarm. Allow it?';
    }
    if (kind === 'system.addEvent') {
      return 'HOPA will add a calendar event. Allow it?';
    }
    if (kind === 'system.openLink') {
      return action.url.length > 0
        ? `HOPA will open:\n\n${action.url}\n\nAllow it?`
        : 'HOPA will open a link. Allow it?';
    }
    if (kind === 'system.delete') {
      return 'HOPA will delete the selected item. Allow it?';
    }
    if (kind === 'system.uninstall') {
      return 'HOPA will uninstall this app. Allow it?';
    }
    if (kind === 'system.call') {
      return 'HOPA will start a call. Allow it?';
    }
    if (kind === 'system.sendMessage') {
      return 'HOPA will send a message. Allow it?';
    }
    if (kind === 'sandbox.run') {
      return 'HOPA will run the script in the offline sandbox. Allow it?';
    }
    return `HOPA will run: ${kind}. Allow it?`;
  }

  private static messageTarget(action: Action, screen: Screen | undefined): string {
    if (action.target.length === 0) {
      return 'the current chat';
    }
    if (screen !== undefined && screen.findRef(action.target) !== undefined) {
      return ApprovalDescription.label(action, screen);
    }
    return action.target;
  }

  private static label(action: Action, screen: Screen | undefined): string {
    if (screen === undefined || action.target.length === 0) {
      return 'this control';
    }
    const node: ScreenNode | undefined = screen.findRef(action.target);
    if (node === undefined) {
      return 'this control';
    }
    if (node.text.length > 0) {
      return ApprovalDescription.shorten(node.text);
    }
    if (node.type.length > 0) {
      return node.type.toLowerCase();
    }
    return 'this control';
  }

  private static appName(bundle: string, names: Map<string, string>): string {
    const display: string | undefined = names.get(bundle.toLowerCase());
    return display === undefined || display.length === 0 ? bundle : display;
  }

  private static shorten(text: string): string {
    const clean: string = text.trim();
    return clean.length <= 200 ? clean : `${clean.substring(0, 199)}…`;
  }
}
