import { Action, ActionCapability, Observation } from '@hopa/core';

/**
 * Implemented by the entry app with public `Want`/`startAbility` calls and the
 * calendar provider. Prefer public abilities over private system APIs.
 */
export interface IntentLauncher {
  setAlarm(hour: number, minute: number, label: string): Promise<boolean>;
  addEvent(title: string, startEpochMs: number, endEpochMs: number): Promise<boolean>;
  openLink(uri: string): Promise<boolean>;
}

/**
 * System intents. Field mapping for the scaffold:
 *   system.setAlarm  -> x = hour, y = minute, text = label
 *   system.addEvent  -> text = title, x = startEpochMs, y = endEpochMs
 *   system.openLink  -> url
 */
export class SystemCapability implements ActionCapability {
  private launcher: IntentLauncher | undefined = undefined;

  setLauncher(launcher: IntentLauncher): void {
    this.launcher = launcher;
  }

  canHandle(kind: string): boolean {
    return kind.startsWith('system.');
  }

  async execute(action: Action): Promise<Observation> {
    if (action.kind === 'system.setAlarm') {
      if (this.launcher !== undefined) {
        await this.launcher.setAlarm(action.x, action.y, action.text);
      }
      return Observation.ok(`alarm prepared for ${action.x}:${action.y}`);
    }

    if (action.kind === 'system.addEvent') {
      if (this.launcher !== undefined) {
        await this.launcher.addEvent(action.text, action.x, action.y);
      }
      return Observation.ok(`calendar event prepared: ${action.text}`);
    }

    if (action.kind === 'system.openLink') {
      if (!action.url.startsWith('https://')) {
        return Observation.fail('deep link rejected: only https URLs are allow-listed');
      }
      if (this.launcher !== undefined) {
        await this.launcher.openLink(action.url);
      }
      return Observation.ok(`deep link prepared: ${action.url}`);
    }

    return Observation.fail(`unsupported system action: ${action.kind}`);
  }
}
