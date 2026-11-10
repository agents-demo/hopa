import { Action, ActionOutcome, GuardResult, Observation, RunRecord, RunStatus } from '../Types';
import { Screen, ScreenSource } from '../domain/Screen';
import { ApprovalPolicy } from './ApprovalPolicy';
import { ActionCapability } from './ActionCapability';
import { ActionGuard } from './ActionGuard';
import { ApprovalGateway } from './ApprovalGateway';
import { RunRecorder } from './RunRecorder';
import { Verifier, AllowAllVerifier } from './Verifier';

export { ActionCapability } from './ActionCapability';
export { ActionGuard } from './ActionGuard';
export { ApprovalGateway } from './ApprovalGateway';
export { RunRecorder } from './RunRecorder';
export { Verifier, AllowAllVerifier } from './Verifier';

export class ActionExecutor {
  private capabilities: ActionCapability[] = [];
  private guards: ActionGuard[] = [];
  private policy: ApprovalPolicy;
  private approvals: ApprovalGateway;
  private recorder: RunRecorder;
  private verifier: Verifier;
  private source?: ScreenSource;

  private static readonly NOOP_KINDS: string[] = [
    'ui.wait',
    'ui.observe',
    'a11y.observe',
    'web.read'
  ];

  constructor(
    policy: ApprovalPolicy,
    approvals: ApprovalGateway,
    recorder: RunRecorder,
    verifier: Verifier = new AllowAllVerifier()
  ) {
    this.policy = policy;
    this.approvals = approvals;
    this.recorder = recorder;
    this.verifier = verifier;
  }

  registerCapability(capability: ActionCapability): void {
    this.capabilities.push(capability);
  }

  addGuard(guard: ActionGuard): void {
    this.guards.push(guard);
  }

  /** Enables real verification: re-observe after the action and compare text. */
  setScreenSource(source: ScreenSource): void {
    this.source = source;
  }

  async execute(action: Action, screen?: Screen): Promise<ActionOutcome> {
    const startedAt: number = Date.now();

    // 1. Guards.
    for (const guard of this.guards) {
      const result: GuardResult = guard.check(action);
      if (!result.allowed) {
        return this.deny(action, RunStatus.Denied, `guard: ${result.reason}`, startedAt);
      }
    }

    // 2. Approval. Payment is fail-closed and always asks.
    let approved: boolean = true;
    if (this.policy.requiresApproval(action, screen)) {
      approved = await this.approvals.requestApproval(action, screen);
      if (!approved) {
        const reason: string = this.policy.isPayment(action, screen)
          ? 'payment denied by user'
          : 'action denied by user';
        return this.deny(action, RunStatus.Denied, reason, startedAt);
      }
    }

    // 3. Execute through the owning capability.
    const capability = this.findCapability(action.kind);
    if (capability === undefined) {
      return this.deny(action, RunStatus.Unsupported, `no capability for ${action.kind}`, startedAt);
    }

    let observation: Observation;
    try {
      observation = await capability.execute(action);
    } catch (error) {
      observation = Observation.fail(`${error}`);
    }

    // 4. Verify: re-observe when a screen source is available.
    const verified: boolean = await this.verifyAfter(action, screen, observation);

    // 5. Record (append-only).
    const status: RunStatus = observation.success ? RunStatus.Executed : RunStatus.Failed;
    const record = new RunRecord(action, status);
    record.approved = approved;
    record.verified = verified;
    record.detail = observation.success ? observation.summary : observation.detail;
    record.startedAt = startedAt;
    record.finishedAt = Date.now();
    record.durationMs = record.finishedAt - record.startedAt;
    this.recorder.record(record);

    const outcome = new ActionOutcome(action, observation);
    outcome.executed = true;
    outcome.approved = approved;
    outcome.verified = verified;
    outcome.recordId = record.id;
    return outcome;
  }

  private async verifyAfter(
    action: Action,
    before: Screen | undefined,
    observation: Observation
  ): Promise<boolean> {
    if (!observation.success) {
      return false;
    }
    if (this.source === undefined || ActionExecutor.NOOP_KINDS.includes(action.kind)) {
      return this.verifier.verify(action, observation);
    }
    const after: Screen = await this.source.capture();
    if (after.text.length === 0) {
      // No observation is not a proven change; keep the capability's verdict.
      return this.verifier.verify(action, observation);
    }
    const beforeText: string = before === undefined ? '' : before.text;
    return after.text !== beforeText;
  }

  private deny(action: Action, status: RunStatus, detail: string, startedAt: number): ActionOutcome {
    const record = new RunRecord(action, status);
    record.approved = false;
    record.detail = detail;
    record.startedAt = startedAt;
    record.finishedAt = Date.now();
    record.durationMs = record.finishedAt - record.startedAt;
    this.recorder.record(record);

    const outcome = new ActionOutcome(action, Observation.fail(detail));
    outcome.executed = false;
    outcome.approved = false;
    outcome.verified = false;
    outcome.recordId = record.id;
    return outcome;
  }

  private findCapability(kind: string): ActionCapability | undefined {
    for (const capability of this.capabilities) {
      if (capability.canHandle(kind)) {
        return capability;
      }
    }
    return undefined;
  }
}
