import { describe, expect, it } from '@ohos/hypium';
import { Action, RiskLevel } from '../main/ets/Types';
import { ApprovalPolicy } from '../main/ets/gate/ApprovalPolicy';
import { Screen } from '../main/ets/domain/Screen';

export default function approvalPolicyTest(): void {
  describe('ApprovalPolicy', () => {
    it('payment_flag_requires_approval', 0, () => {
      const policy = new ApprovalPolicy();
      const action = new Action('ui.tap');
      action.isPayment = true;
      expect(policy.isPayment(action)).assertTrue();
      expect(policy.requiresApproval(action)).assertTrue();
      expect(policy.classify(action)).assertEqual(RiskLevel.Payment);
    });

    it('checkout_kind_is_payment_without_flag', 0, () => {
      const policy = new ApprovalPolicy();
      const action = new Action('payment.checkout');
      expect(policy.isPayment(action)).assertTrue();
      expect(policy.requiresApproval(action)).assertTrue();
    });

    it('allow_listed_action_needs_no_approval', 0, () => {
      const policy = new ApprovalPolicy();
      const action = new Action('ui.tap');
      expect(policy.classify(action)).assertEqual(RiskLevel.Read);
      expect(policy.requiresApproval(action)).assertFalse();
    });

    it('sensitive_action_requires_approval', 0, () => {
      const policy = new ApprovalPolicy();
      expect(policy.requiresApproval(new Action('ui.sendMessage'))).assertTrue();
      expect(policy.requiresApproval(new Action('system.delete'))).assertTrue();
    });

    it('unknown_action_is_fail_closed', 0, () => {
      const policy = new ApprovalPolicy();
      const action = new Action('custom.unknown');
      expect(policy.isPayment(action)).assertFalse();
      expect(policy.classify(action)).assertEqual(RiskLevel.Sensitive);
      expect(policy.requiresApproval(action)).assertTrue();
    });

    it('payment_screen_tap_requires_approval', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Checkout\nTotal ¥9.99\nPay now');
      const action = new Action('ui.tap');
      expect(policy.isPaymentScreen(screen)).assertTrue();
      expect(policy.isPayment(action, screen)).assertTrue();
      expect(policy.requiresApproval(action, screen)).assertTrue();
    });

    it('web_navigate_is_not_a_payment', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Checkout\nTotal ¥9.99\nPay now\nI always ask before any payment.');
      const action = new Action('web.navigate');
      action.url = 'https://bilibili.com';
      expect(policy.isPayment(action, screen)).assertFalse();
      expect(policy.requiresApproval(action, screen)).assertFalse();
    });

    it('payment_prose_is_not_a_payment', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen(
        'I always ask before any payment.\n' +
        'Payment is always confirmed. This cannot be changed.\n' +
        'Never skips a payment.'
      );
      const action = new Action('ui.tap');
      expect(policy.isPaymentScreen(screen)).assertFalse();
      expect(policy.isPayment(action, screen)).assertFalse();
      expect(policy.requiresApproval(action, screen)).assertFalse();
    });

    it('model_flag_cannot_clear_screen_payment', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Checkout Total ¥9.99');
      const action = new Action('ui.tap');
      action.isPayment = false;
      expect(policy.isPayment(action, screen)).assertTrue();
    });

    it('payment_screen_observe_is_read_only', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Checkout Total ¥9.99');
      expect(policy.requiresApproval(new Action('ui.observe'), screen)).assertFalse();
      expect(policy.requiresApproval(new Action('ui.back'), screen)).assertFalse();
    });

    it('ui_launch_is_allow_listed', 0, () => {
      const policy = new ApprovalPolicy();
      expect(policy.requiresApproval(new Action('ui.launch'))).assertFalse();
      expect(policy.classify(new Action('ui.launch'))).assertEqual(RiskLevel.Read);
    });

    it('autonomous_skips_sensitive_but_never_payment', 0, () => {
      const policy = new ApprovalPolicy();
      policy.setAutonomous(true);
      expect(policy.isAutonomous()).assertTrue();
      expect(policy.requiresApproval(new Action('ui.sendMessage'))).assertFalse();
      expect(policy.requiresApproval(new Action('payment.confirm'))).assertTrue();
      const screen = new Screen('Checkout\nTotal ¥9.99\nPay now');
      expect(policy.requiresApproval(new Action('ui.tap'), screen)).assertTrue();
    });

    it('ask_mode_still_asks_for_sensitive_actions', 0, () => {
      const policy = new ApprovalPolicy();
      expect(policy.requiresApproval(new Action('ui.sendMessage'))).assertTrue();
    });

    it('extracts_amount_and_currency', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Checkout\nTotal ¥1,299.00\nPay now');
      const context = policy.extractPaymentContext(screen);
      expect(context.amount).assertEqual('¥1,299.00');
      expect(context.currency).assertEqual('¥');
      expect(context.hasDetails()).assertTrue();
    });

    it('extracts_merchant_line', 0, () => {
      const policy = new ApprovalPolicy();
      const screen = new Screen('Merchant: Blue Cafe\nAmount $4.50');
      const context = policy.extractPaymentContext(screen);
      expect(context.merchant).assertEqual('Blue Cafe');
      expect(context.amount).assertEqual('$4.50');
    });

    it('does_not_invent_payment_details', 0, () => {
      const policy = new ApprovalPolicy();
      const context = policy.extractPaymentContext(new Screen('Chat with a friend'));
      expect(context.amount).assertEqual('');
      expect(context.merchant).assertEqual('');
      expect(context.hasDetails()).assertFalse();
    });

    it('empty_screen_has_no_details', 0, () => {
      const policy = new ApprovalPolicy();
      expect(policy.extractPaymentContext().hasDetails()).assertFalse();
    });
  });
}
