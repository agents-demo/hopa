import { Action, RiskLevel } from './Types';
import { Screen } from './Screen';

/**
 * Amount, currency and merchant read from the screen. Best effort: a missing
 * field is shown as "not visible" rather than guessed.
 */
export class PaymentContext {
  amount: string = '';
  currency: string = '';
  merchant: string = '';
  readonly consequence: string =
    'Money may leave your account. HOPA cannot undo a payment.';

  hasDetails(): boolean {
    return this.amount.length > 0 || this.merchant.length > 0;
  }
}

/**
 * The single source of truth for approval.
 *
 * Payment is detected from the action and the screen, never from a model flag.
 * It is always `ask` and is never remembered. Unknown action kinds are treated
 * as sensitive (fail-closed).
 */
export class ApprovalPolicy {
  private autonomous: boolean = false;

  setAutonomous(autonomous: boolean): void {
    this.autonomous = autonomous;
  }

  isAutonomous(): boolean {
    return this.autonomous;
  }
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
    'ui.launch',
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
    // Payment is never autonomous. This is the one hard rule.
    if (this.isPayment(action, screen)) {
      return true;
    }
    if (this.autonomous) {
      return false;
    }
    return this.classify(action, screen) !== RiskLevel.Read;
  }

  /**
   * Reads an amount, a currency and a merchant from the visible text. It never
   * invents a value: an empty field means the screen did not show it.
   */
  extractPaymentContext(screen?: Screen): PaymentContext {
    const context = new PaymentContext();
    if (screen === undefined) {
      return context;
    }
    const lines: string[] = screen.text.split('\n');
    for (const line of lines) {
      const text: string = line.trim();
      if (text.length === 0) {
        continue;
      }
      if (context.amount.length === 0) {
        const match = text.match(/(?:[¥$€£]|CNY|USD|EUR|GBP)\s?\d[\d,]*(?:\.\d{1,2})?/i);
        if (match !== null) {
          context.amount = match[0].trim();
          const currency = context.amount.match(/[¥$€£]|CNY|USD|EUR|GBP/i);
          if (currency !== null) {
            context.currency = currency[0];
          }
        }
      }
      if (context.merchant.length === 0) {
        const lower: string = text.toLowerCase();
        if (lower.startsWith('merchant:') || text.startsWith('商户')) {
          const index: number = text.indexOf(':');
          context.merchant = index >= 0 ? text.substring(index + 1).trim() : text;
        }
      }
    }
    return context;
  }
}
