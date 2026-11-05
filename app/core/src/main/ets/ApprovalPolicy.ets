import { Action, RiskLevel } from './Types';

/**
 * The single source of truth for approval.
 *
 * Payment is always `ask` and is never remembered or auto-approved. Unknown
 * action kinds are treated as sensitive (fail-closed): adding a new capability
 * without classifying it will require user approval rather than silently run.
 */
export class ApprovalPolicy {
  private paymentKinds: Set<string> = new Set<string>([
    'payment.pay',
    'payment.confirm',
    'payment.checkout',
    'payment.enterCard',
    'payment.authorize'
  ]);

  private sensitiveKinds: Set<string> = new Set<string>([
    'ui.sendMessage',
    'ui.call',
    'system.delete',
    'system.uninstall',
    'system.reset',
    'sandbox.runNetworked'
  ]);

  // Explicitly allow-listed, non-destructive actions. Anything not listed here
  // (and not payment) falls through to Sensitive.
  private allowedKinds: Set<string> = new Set<string>([
    'web.navigate',
    'web.read',
    'web.click',
    'web.type',
    'ui.tap',
    'ui.type',
    'ui.swipe',
    'ui.observe',
    'a11y.observe',
    'system.setAlarm',
    'system.addEvent',
    'system.openLink',
    'sandbox.run'
  ]);

  classify(action: Action): RiskLevel {
    if (action.isPayment || this.paymentKinds.has(action.kind)) {
      return RiskLevel.Payment;
    }
    if (this.sensitiveKinds.has(action.kind)) {
      return RiskLevel.Sensitive;
    }
    if (this.allowedKinds.has(action.kind)) {
      return RiskLevel.Read;
    }
    return RiskLevel.Sensitive;
  }

  isPayment(action: Action): boolean {
    return this.classify(action) === RiskLevel.Payment;
  }

  requiresApproval(action: Action): boolean {
    return this.classify(action) !== RiskLevel.Read;
  }
}
