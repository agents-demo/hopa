/**
 * Compatibility barrel for the core value types.
 *
 * The definitions live one per file under ./domain. New code imports the
 * specific file; this barrel keeps the public API stable during the split.
 */
export { RunStatus } from './domain/RunStatus';
export { RiskLevel } from './domain/RiskLevel';
export { Action } from './domain/Action';
export { Observation } from './domain/Observation';
export { ActionOutcome } from './domain/ActionOutcome';
export { GuardResult } from './domain/GuardResult';
export { RunRecord } from './domain/RunRecord';
