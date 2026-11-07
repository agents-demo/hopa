import { Action } from './Action';
import { Observation } from './Observation';

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
