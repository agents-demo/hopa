/**
 * Core value types for HOPA.
 *
 * This module is plain ArkTS: no ArkUI imports, no page code. Everything here is
 * host-testable with Local Test.
 */

export enum RunStatus {
  Executed = 'executed',
  Denied = 'denied',
  Failed = 'failed',
  Unsupported = 'unsupported'
}

export enum RiskLevel {
  Read = 'read',
  Sensitive = 'sensitive',
  Payment = 'payment'
}

/**
 * A proposed device/browser/system action. The executor owns risk classification;
 * a model never sets `isPayment`.
 */
export class Action {
  id: string;
  kind: string;
  target: string = '';
  text: string = '';
  url: string = '';
  app: string = '';
  x: number = 0;
  y: number = 0;
  toX: number = 0;
  toY: number = 0;
  isPayment: boolean = false;

  constructor(kind: string) {
    this.id = `action-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    this.kind = kind;
  }
}

/** The observed result of executing an action. */
export class Observation {
  success: boolean = false;
  summary: string = '';
  detail: string = '';
  layoutHash: string = '';
  screenshotRef: string = '';

  static ok(summary: string): Observation {
    const observation = new Observation();
    observation.success = true;
    observation.summary = summary;
    return observation;
  }

  static fail(detail: string): Observation {
    const observation = new Observation();
    observation.success = false;
    observation.detail = detail;
    return observation;
  }
}

/** The result returned by ActionExecutor.execute(). */
export class ActionOutcome {
  action: Action;
  executed: boolean = false;
  approved: boolean = false;
  verified: boolean = false;
  observation: Observation;
  recordId: string = '';

  constructor(action: Action, observation: Observation) {
    this.action = action;
    this.observation = observation;
  }
}

export class GuardResult {
  allowed: boolean;
  reason: string;

  constructor(allowed: boolean, reason: string = '') {
    this.allowed = allowed;
    this.reason = reason;
  }
}

/** Append-only audit record for one action. */
export class RunRecord {
  id: string;
  actionId: string;
  kind: string;
  isPayment: boolean;
  approved: boolean = false;
  status: RunStatus;
  detail: string = '';
  startedAt: number;
  finishedAt: number;
  durationMs: number = 0;

  constructor(action: Action, status: RunStatus) {
    this.id = `run-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    this.actionId = action.id;
    this.kind = action.kind;
    this.isPayment = action.isPayment;
    this.status = status;
    this.startedAt = Date.now();
    this.finishedAt = this.startedAt;
  }
}
