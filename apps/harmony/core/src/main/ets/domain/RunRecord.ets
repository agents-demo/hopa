import { Action } from './Action';
import { RunStatus } from './RunStatus';

/** Append-only audit record for one action. */
export class RunRecord {
  id: string;
  actionId: string;
  kind: string;
  /** Which conversation turn this action belonged to; '' for older records. */
  turnId: string = '';
  isPayment: boolean;
  approved: boolean = false;
  /** The executor re-observed the screen and saw a change. */
  verified: boolean = false;
  /** Sandbox path of the step thumbnail, or ''. */
  shot: string = '';
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
