import { Action } from '../Types';
import { GuardResult } from '../Types';

/** A pre-execution guard (allow-list, preconditions, destructive limits). */
export interface ActionGuard {
  check(action: Action): GuardResult;
}
