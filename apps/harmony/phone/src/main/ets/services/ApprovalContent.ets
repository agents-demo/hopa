import { Action, ApprovalDescription, ApprovalPolicy, PaymentContext, Screen } from '@hopa/core';
import { AppRouteTargets } from './AppRouteTargets';

/** The title and body shown in the approval sheet. */
export class ApprovalContent {
  title: string = '';
  message: string = '';
  payment: boolean = false;
  /** Bounds of the target in device pixels, and the screen frame, for the cue. */
  highlightX1: number = 0;
  highlightY1: number = 0;
  highlightX2: number = 0;
  highlightY2: number = 0;
  frameWidth: number = 0;
  frameHeight: number = 0;
  highlightLabel: string = '';
  /** Non-empty only for an outgoing message from a named app. */
  rememberBundle: string = '';
  rememberLabel: string = '';
}

export class ApprovalContentBuilder {
  /** Human text, with the amount and merchant when the action is a payment. */
  static describe(
    policy: ApprovalPolicy,
    action: Action,
    screen: Screen | undefined
  ): ApprovalContent {
    const content = new ApprovalContent();
    const names = AppRouteTargets.displayNames();
    content.payment = policy.isPayment(action, screen);
    ApprovalContentBuilder.markTarget(content, action, screen);
    if (!content.payment && action.kind === 'ui.sendMessage' && action.app.length > 0) {
      content.rememberBundle = action.app;
      const display: string | undefined = names.get(action.app.toLowerCase());
      content.rememberLabel = display === undefined ? action.app : display;
    }
    if (!content.payment) {
      content.title = ApprovalDescription.title(action, screen, names);
      content.message = ApprovalDescription.body(action, screen, names);
      return content;
    }
    const context: PaymentContext = policy.extractPaymentContext(screen);
    const amount: string = context.amount.length > 0 ? context.amount : 'not visible';
    const merchant: string = context.merchant.length > 0 ? context.merchant : 'not visible';
    content.title = 'Confirm payment?';
    content.message = `HOPA wants to run: ${action.kind}\n\n` +
      `Amount: ${amount}\nMerchant: ${merchant}\n\n` +
      `${context.consequence}\n\n` +
      'Check the next screen yourself before you confirm.\n\nAllow it?';
    return content;
  }

  /** A screen-map cue: the target bounds plus the frame they belong to. */
  private static markTarget(content: ApprovalContent, action: Action, screen: Screen | undefined): void {
    if (screen === undefined || action.target.length === 0) {
      return;
    }
    const node = screen.findRef(action.target);
    if (node === undefined || node.bounds.length !== 4) {
      return;
    }
    let maxX: number = 0;
    let maxY: number = 0;
    for (const item of screen.nodes) {
      if (item.bounds.length === 4) {
        maxX = Math.max(maxX, item.bounds[2]);
        maxY = Math.max(maxY, item.bounds[3]);
      }
    }
    if (maxX <= 0 || maxY <= 0) {
      return;
    }
    content.highlightX1 = node.bounds[0];
    content.highlightY1 = node.bounds[1];
    content.highlightX2 = node.bounds[2];
    content.highlightY2 = node.bounds[3];
    content.frameWidth = maxX;
    content.frameHeight = maxY;
    content.highlightLabel = node.text.length > 0
      ? node.text
      : (node.type.length > 0 ? node.type : 'this control');
  }
}
