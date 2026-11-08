import { Action } from '../Types';
import { Observation } from '../Types';

/** Compares the intended effect with the observation. */
export interface Verifier {
  verify(action: Action, observation: Observation): boolean;
}

export class AllowAllVerifier implements Verifier {
  verify(action: Action, observation: Observation): boolean {
    return observation.success;
  }
}
