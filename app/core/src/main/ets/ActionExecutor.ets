import { Action, ActionOutcome, GuardResult, Observation, RunRecord, RunStatus } from './Types';
import { ApprovalPolicy } from './ApprovalPolicy';
import { Screen } from './Screen';

/** A capability that can execute one or more action kinds. */
export interface ActionCapability {
  canHandle(kind: string): boolean;
  execute(action: Action): Promise<Observation>;
}

/** A pre-execution guard (allow-list, preconditions, destructive limits). */
export interface ActionGuard {
  check(action: Action): GuardResult;
}

/** The UI/notification channel used to ask the user. */
export interface ApprovalGateway {
  requestApproval(action: Action, screen?: Screen): Promise<boolean>;
}

/** Append-only run record sink. */
export interface RunRecorder {
  record(run: RunRecord): void;
}

/** Compares the intended effect with the observation. */
export interface Verifier {
  verify(action: Action, observation: Observation): boolean;
}

export class AllowAllVerifier implements Verifier {
  verify(action: Action, observation: Observation): boolean {
    return observation.success;
  }
}

/**
 * THE action gate. Every capability action must pass through execute().
 *
 * Pipeline (do not reorder):
 *   guards -> payment approval -> execute -> verify -> record
 */
export class ActionExecutor {
  private capabilities: ActionCapability[] = [];
  private guards: ActionGuard[] = [];
  private policy: ApprovalPolicy;
  private approvals: ApprovalGateway;
  private recorder: RunRecorder;
  private verifier: Verifier;

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

  async execute(action: Action, screen?: Screen): Promise<ActionOutcome> {
    // 1. Guards.
    for (const guard of this.guards) {
      const result: GuardResult = guard.check(action);
      if (!result.allowed) {
        return this.deny(action, RunStatus.Denied, `guard: ${result.reason}`);
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
        return this.deny(action, RunStatus.Denied, reason);
      }
    }

    // 3. Execute through the owning capability.
    const capability = this.findCapability(action.kind);
    if (capability === undefined) {
      return this.deny(action, RunStatus.Unsupported, `no capability for ${action.kind}`);
    }

    let observation: Observation;
    try {
      observation = await capability.execute(action);
    } catch (error) {
      observation = Observation.fail(`${error}`);
    }

    // 4. Verify.
    const verified: boolean = this.verifier.verify(action, observation);

    // 5. Record (append-only).
    const status: RunStatus = observation.success ? RunStatus.Executed : RunStatus.Failed;
    const record = new RunRecord(action, status);
    record.approved = approved;
    record.detail = observation.success ? observation.summary : observation.detail;
    record.finishedAt = Date.now();
    this.recorder.record(record);

    const outcome = new ActionOutcome(action, observation);
    outcome.executed = true;
    outcome.approved = approved;
    outcome.verified = verified;
    outcome.recordId = record.id;
    return outcome;
  }

  private deny(action: Action, status: RunStatus, detail: string): ActionOutcome {
    const record = new RunRecord(action, status);
    record.approved = false;
    record.detail = detail;
    record.finishedAt = Date.now();
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
