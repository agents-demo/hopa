import { Action } from '../Types';
import { Observation } from '../Types';

/** A capability that can execute one or more action kinds. */
export interface ActionCapability {
  canHandle(kind: string): boolean;
  execute(action: Action): Promise<Observation>;
}
