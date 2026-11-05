import { Action, ActionCapability, Observation } from '@hopa/core';

/**
 * Accessibility capability.
 *
 * DEPENDS ON A RESTRICTED PERMISSION AND AN ACL REQUEST. It refuses to act until
 * the app has the approved ACL, the extension is declared, and the user enables
 * the HOPA accessibility service in Settings -> Accessibility. The entry app must
 * surface this as unavailable until then.
 */
export class A11yCapability implements ActionCapability {
  private available: boolean = false;

  setAvailable(available: boolean): void {
    this.available = available;
  }

  isAvailable(): boolean {
    return this.available;
  }

  canHandle(kind: string): boolean {
    return kind.startsWith('a11y.');
  }

  async execute(action: Action): Promise<Observation> {
    if (!this.available) {
      return Observation.fail(
        'accessibility unavailable: restricted permission/ACL not granted or service disabled'
      );
    }
    return Observation.ok(`a11y action accepted: ${action.kind}`);
  }
}
