import { Action } from '../Types';
import { Screen } from '../domain/Screen';

/** The UI/notification channel used to ask the user. */
export interface ApprovalGateway {
  requestApproval(action: Action, screen?: Screen): Promise<boolean>;
}
