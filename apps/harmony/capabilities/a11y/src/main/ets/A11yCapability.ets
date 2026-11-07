import { Action, ActionCapability, Observation } from '@hopa/core';
import { A11yBridge } from './A11yBridge';

/**
 * Accessibility capability.
 *
 * DEPENDS ON A RESTRICTED PERMISSION AND AN ACL REQUEST. It refuses to act until
 * the app has the approved ACL, the extension is declared, and the user enables
 * the HOPA accessibility service in Settings -> Accessibility.
 */
export class A11yCapability implements ActionCapability {
  private available: boolean = false;

  setAvailable(available: boolean): void {
    this.available = available;
  }

  isAvailable(): boolean {
    return this.available || A11yBridge.get().isAvailable();
  }

  canHandle(kind: string): boolean {
    return kind === 'a11y.observe';
  }

  async execute(action: Action): Promise<Observation> {
    if (!this.isAvailable()) {
      return Observation.fail(
        'accessibility unavailable: restricted permission/ACL not granted or service disabled'
      );
    }
    if (action.kind === 'a11y.observe') {
      const screen = await A11yBridge.get().capture();
      return Observation.ok(
        screen.text.length > 0 ? screen.text.substring(0, 120) : 'screen captured'
      );
    }
    return Observation.ok(`a11y action accepted: ${action.kind}`);
  }
}
