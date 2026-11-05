import { describe, expect, it } from '@ohos/hypium';
import { Action, RiskLevel } from '../main/ets/Types';
import { ApprovalPolicy } from '../main/ets/ApprovalPolicy';

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
  });
}
