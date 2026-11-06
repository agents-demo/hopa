import { describe, expect, it } from '@ohos/hypium';
import {
  Action,
  ActionOutcome,
  GuardResult,
  Observation,
  RunRecord,
  RunStatus
} from '../main/ets/Types';
import { ApprovalPolicy } from '../main/ets/ApprovalPolicy';
import {
  ActionCapability,
  ActionExecutor,
  ActionGuard,
  ApprovalGateway,
  RunRecorder
} from '../main/ets/ActionExecutor';
import { Screen } from '../main/ets/Screen';

class RecordingCapability implements ActionCapability {
  executions: number = 0;

  canHandle(kind: string): boolean {
    return kind.startsWith('ui.') || kind.startsWith('payment.');
  }

  async execute(action: Action): Promise<Observation> {
    this.executions++;
    return Observation.ok('done');
  }
}

class FixedApproval implements ApprovalGateway {
  private answer: boolean;
  requests: number = 0;

  constructor(answer: boolean) {
    this.answer = answer;
  }

  async requestApproval(action: Action): Promise<boolean> {
    this.requests++;
    return this.answer;
  }
}

class MemoryRecorder implements RunRecorder {
  records: RunRecord[] = [];

  record(run: RunRecord): void {
    this.records.push(run);
  }
}

class DenyGuard implements ActionGuard {
  check(action: Action): GuardResult {
    return new GuardResult(false, 'blocked by test guard');
  }
}

class Harness {
  executor: ActionExecutor;
  capability: RecordingCapability;
  approval: FixedApproval;
  recorder: MemoryRecorder;

  constructor(approved: boolean) {
    this.capability = new RecordingCapability();
    this.approval = new FixedApproval(approved);
    this.recorder = new MemoryRecorder();
    this.executor = new ActionExecutor(new ApprovalPolicy(), this.approval, this.recorder);
    this.executor.registerCapability(this.capability);
  }
}

export default function actionExecutorTest(): void {
  describe('ActionExecutor', () => {
    it('payment_without_approval_is_never_executed', 0, async (done: Function) => {
      const harness = new Harness(false);
      const action = new Action('ui.tap');
      action.isPayment = true;

      const outcome: ActionOutcome = await harness.executor.execute(action);

      expect(outcome.executed).assertFalse();
      expect(outcome.approved).assertFalse();
      expect(harness.capability.executions).assertEqual(0);
      expect(harness.approval.requests).assertEqual(1);
      expect(harness.recorder.records.length).assertEqual(1);
      expect(harness.recorder.records[0].status).assertEqual(RunStatus.Denied);
      done();
    });

    it('payment_with_approval_executes_and_records', 0, async (done: Function) => {
      const harness = new Harness(true);
      const action = new Action('payment.confirm');

      const outcome: ActionOutcome = await harness.executor.execute(action);

      expect(outcome.executed).assertTrue();
      expect(outcome.approved).assertTrue();
      expect(harness.capability.executions).assertEqual(1);
      expect(harness.recorder.records[0].approved).assertTrue();
      expect(harness.recorder.records[0].status).assertEqual(RunStatus.Executed);
      done();
    });

    it('read_action_does_not_ask', 0, async (done: Function) => {
      const harness = new Harness(false);
      const outcome = await harness.executor.execute(new Action('ui.tap'));

      expect(outcome.executed).assertTrue();
      expect(harness.approval.requests).assertEqual(0);
      done();
    });

    it('guard_runs_before_execution', 0, async (done: Function) => {
      const harness = new Harness(true);
      harness.executor.addGuard(new DenyGuard());

      const outcome = await harness.executor.execute(new Action('ui.tap'));

      expect(outcome.executed).assertFalse();
      expect(harness.capability.executions).assertEqual(0);
      expect(harness.recorder.records[0].status).assertEqual(RunStatus.Denied);
      done();
    });

    it('unknown_capability_is_unsupported', 0, async (done: Function) => {
      const harness = new Harness(true);
      const action = new Action('a11y.observe');

      const outcome = await harness.executor.execute(action);

      expect(outcome.executed).assertFalse();
      expect(harness.recorder.records[0].status).assertEqual(RunStatus.Unsupported);
      done();
    });

    it('payment_screen_tap_without_approval_is_denied', 0, async (done: Function) => {
      const harness = new Harness(false);
      const screen = new Screen('Checkout\nTotal ¥9.99\nPay now');

      const outcome = await harness.executor.execute(new Action('ui.tap'), screen);

      expect(outcome.executed).assertFalse();
      expect(outcome.approved).assertFalse();
      expect(harness.capability.executions).assertEqual(0);
      expect(harness.approval.requests).assertEqual(1);
      expect(harness.recorder.records[0].status).assertEqual(RunStatus.Denied);
      done();
    });

    it('payment_screen_tap_with_approval_executes', 0, async (done: Function) => {
      const harness = new Harness(true);
      const screen = new Screen('Checkout\nTotal ¥9.99');

      const outcome = await harness.executor.execute(new Action('ui.tap'), screen);

      expect(outcome.executed).assertTrue();
      expect(outcome.approved).assertTrue();
      expect(harness.approval.requests).assertEqual(1);
      expect(harness.capability.executions).assertEqual(1);
      done();
    });
  });
}
