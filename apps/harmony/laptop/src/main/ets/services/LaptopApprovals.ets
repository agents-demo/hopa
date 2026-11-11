import { Action, ApprovalGateway, Screen } from '@hopa/core';

/**
 * The laptop's consent channel.
 *
 * It does not decide anything: it surfaces the action to the page, which shows
 * a card, and waits for Allow or Not now. Until then the run is paused, which
 * is the same contract the phone's approval sheet uses.
 */
export class LaptopApprovals implements ApprovalGateway {
  onAsk: ((kind: string, detail: string) => void) | null = null;
  private resolver: ((allow: boolean) => void) | undefined = undefined;

  async requestApproval(action: Action, screen?: Screen): Promise<boolean> {
    const detail: string = this.describe(action);
    return new Promise<boolean>((resolve: (allow: boolean) => void) => {
      this.resolver = resolve;
      if (this.onAsk !== null) {
        this.onAsk(action.kind, detail);
      } else {
        // No listener means no consent path: refuse rather than hang.
        this.resolver = undefined;
        resolve(false);
      }
    });
  }

  answer(allow: boolean): void {
    const resolve: ((allow: boolean) => void) | undefined = this.resolver;
    this.resolver = undefined;
    if (resolve !== undefined) {
      resolve(allow);
    }
  }

  private describe(action: Action): string {
    if (action.isPayment) {
      return 'This spends money.';
    }
    if (action.kind === 'system.sendMessage') {
      return action.target.length > 0 ? `Send a message to ${action.target}.` : 'Send a message.';
    }
    if (action.kind === 'system.call') {
      return action.target.length > 0 ? `Call ${action.target}.` : 'Place a call.';
    }
    if (action.kind === 'system.share') {
      return 'Share something outside HOPA.';
    }
    if (action.kind === 'system.openLink') {
      return action.url.length > 0 ? `Open ${action.url}.` : 'Open a link.';
    }
    if (action.kind === 'sandbox.run') {
      return 'Run a script.';
    }
    return action.kind.length > 0 ? `Do ${action.kind}.` : 'Do something outside HOPA.';
  }
}
