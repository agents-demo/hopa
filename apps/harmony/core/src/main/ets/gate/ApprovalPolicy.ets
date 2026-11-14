import { Action, RiskLevel } from '../Types';
import { Screen } from '../domain/Screen';
import {
  ALLOWED_KINDS,
  CURRENCY_RE,
  CURRENCY_TOKEN_RE,
  INTERACTIVE_KINDS,
  MERCHANT_PREFIXES,
  PAYMENT_ACTIONS,
  PAYMENT_CONSEQUENCE,
  PAYMENT_KINDS,
  PAYMENT_WORDS,
  SENSITIVE_KINDS,
  TOTAL_RE,
  TRUSTED_APP_KINDS
} from './PolicyData';

/**
 * Amount, currency and merchant read from the screen. Best effort: a missing
 * field is shown as "not visible" rather than guessed.
 */
export class PaymentContext {
  amount: string = '';
  currency: string = '';
  merchant: string = '';
  readonly consequence: string = PAYMENT_CONSEQUENCE;

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

  /** Apps the user trusts for outgoing messages. Never for payments. */
  private trustedApps: Set<string> = new Set<string>();

  setTrustedApps(apps: string[]): void {
    this.trustedApps.clear();
    for (const app of apps) {
      const key: string = app.trim().toLowerCase();
      if (key.length > 0) {
        this.trustedApps.add(key);
      }
    }
  }

  isTrustedApp(bundle: string): boolean {
    return this.trustedApps.has(bundle.trim().toLowerCase());
  }
  private paymentKinds: Set<string> = new Set<string>(PAYMENT_KINDS);

  private paymentWords: string[] = PAYMENT_WORDS;

  private paymentActions: string[] = PAYMENT_ACTIONS;

  private interactiveKinds: Set<string> = new Set<string>(INTERACTIVE_KINDS);

  private sensitiveKinds: Set<string> = new Set<string>(SENSITIVE_KINDS);

  // Explicitly allow-listed, non-destructive actions. Anything not listed here
  // (and not payment) falls through to Sensitive.
  private allowedKinds: Set<string> = new Set<string>(ALLOWED_KINDS);

  /**
   * A payment screen must show a real checkout signal: an amount together
   * with checkout/order language, or an exact pay-action label. Prose such as
   * "I always ask before any payment" is not a payment.
   */
  isPaymentScreen(screen?: Screen): boolean {
    if (screen === undefined) {
      return false;
    }
    const text: string = screen.text;
    if (this.hasPaymentAction(text)) {
      return true;
    }
    return this.hasAmount(text) && screen.containsAny(this.paymentWords);
  }

  private hasPaymentAction(text: string): boolean {
    for (const line of text.split('\n')) {
      const trimmed: string = line.trim().toLowerCase();
      if (trimmed.length === 0 || trimmed.length > 24) {
        continue;
      }
      for (const label of this.paymentActions) {
        if (trimmed === label) {
          return true;
        }
      }
    }
    return false;
  }

  private hasAmount(text: string): boolean {
    if (CURRENCY_RE.test(text)) {
      return true;
    }
    return TOTAL_RE.test(text);
  }

  private isTrustedKind(kind: string): boolean {
    for (const trustedKind of TRUSTED_APP_KINDS) {
      if (trustedKind === kind) {
        return true;
      }
    }
    return false;
  }

  classify(action: Action, screen?: Screen): RiskLevel {
    if (action.isPayment || this.paymentKinds.has(action.kind)) {
      return RiskLevel.Payment;
    }
    if (this.isPaymentScreen(screen) && this.interactiveKinds.has(action.kind)) {
      return RiskLevel.Payment;
    }
    // A remembered app skips the message prompt only. Delete, call, payment and
    // unknown kinds keep asking.
    if (this.isTrustedKind(action.kind) && action.app.length > 0 &&
      this.trustedApps.has(action.app.toLowerCase())) {
      return RiskLevel.Read;
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
        const match = text.match(CURRENCY_RE);
        if (match !== null) {
          context.amount = match[0].trim();
          const currency = context.amount.match(CURRENCY_TOKEN_RE);
          if (currency !== null) {
            context.currency = currency[0];
          }
        }
      }
      if (context.merchant.length === 0) {
        const lower: string = text.toLowerCase();
        let hasPrefix: boolean = false;
        for (const prefix of MERCHANT_PREFIXES) {
          if (lower.startsWith(prefix)) {
            hasPrefix = true;
            break;
          }
        }
        if (hasPrefix) {
          const index: number = text.indexOf(':');
          context.merchant = index >= 0 ? text.substring(index + 1).trim() : text;
        }
      }
    }
    return context;
  }
}
