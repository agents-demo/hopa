import { Action, RiskLevel } from './Types';
import { Screen } from './Screen';

/**
 * The single source of truth for approval.
 *
 * Payment is detected from the action and the screen, never from a model flag.
 * It is always `ask` and is never remembered. Unknown action kinds are treated
 * as sensitive (fail-closed).
 */
export class ApprovalPolicy {
  private paymentKinds: Set<string> = new Set<string>([
    'payment.pay',
    'payment.confirm',
    'payment.checkout',
    'payment.enterCard',
    'payment.authorize'
  ]);

  private paymentWords: string[] = [
    'pay',
    'payment',
    'checkout',
    'confirm order',
    'place order',
    'buy now',
    'purchase',
    'subscribe',
    'amount',
    'total',
    'merchant',
    'currency',
    'card number',
    '支付',
    '付款',
    '结算',
    '确认订单',
    '立即购买',
    '金额',
    '商户',
    '银行卡'
  ];

  private interactiveKinds: Set<string> = new Set<string>([
    'ui.tap',
    'ui.doubleTap',
    'ui.longPress',
    'ui.type',
    'ui.swipe',
    'ui.scroll',
    'web.navigate',
    'web.click',
    'web.type'
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
    'ui.doubleTap',
    'ui.longPress',
    'ui.type',
    'ui.swipe',
    'ui.scroll',
    'ui.back',
    'ui.home',
    'ui.wait',
    'ui.observe',
    'a11y.observe',
    'system.setAlarm',
    'system.addEvent',
    'system.openLink',
    'sandbox.run'
  ]);

  isPaymentScreen(screen?: Screen): boolean {
    if (screen === undefined) {
      return false;
    }
    return screen.containsAny(this.paymentWords);
  }

  classify(action: Action, screen?: Screen): RiskLevel {
    if (action.isPayment || this.paymentKinds.has(action.kind)) {
      return RiskLevel.Payment;
    }
    if (this.isPaymentScreen(screen) && this.interactiveKinds.has(action.kind)) {
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

  isPayment(action: Action, screen?: Screen): boolean {
    return this.classify(action, screen) === RiskLevel.Payment;
  }

  requiresApproval(action: Action, screen?: Screen): boolean {
    return this.classify(action, screen) !== RiskLevel.Read;
  }
}
