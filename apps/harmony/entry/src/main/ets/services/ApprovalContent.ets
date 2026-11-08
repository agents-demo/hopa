import { Action, ApprovalDescription, ApprovalPolicy, PaymentContext, Screen } from '@hopa/core';
import { AppRouteTargets } from './AppRouteTargets';

/** The title and body shown in the approval sheet. */
export class ApprovalContent {
  title: string = '';
  message: string = '';
  payment: boolean = false;
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
}
