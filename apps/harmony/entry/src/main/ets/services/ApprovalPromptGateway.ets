import { Action, ApprovalGateway, Screen } from '@hopa/core';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Called when an action needs the user's decision. Must be fail-closed. */
export type ApprovalPrompt = (action: Action, screen: Screen | undefined) => Promise<boolean>;

/**
 * Approval gateway backed by the ArkUI sheet. Until the page installs a
 * handler, every request is denied: the default is never "allow".
 */
export class UiApprovalGateway implements ApprovalGateway {
  private handler: ApprovalPrompt | undefined = undefined;

  setHandler(handler: ApprovalPrompt | undefined): void {
    this.handler = handler;
  }

  async requestApproval(action: Action, screen?: Screen): Promise<boolean> {
    if (this.handler === undefined) {
      return false;
    }
    hilog.info(0x0000, 'HOPA', `approval: ask ${action.kind}`);
    const approved: boolean = await this.handler(action, screen);
    hilog.info(0x0000, 'HOPA', `approval: answer ${approved}`);
    return approved;
  }
}
