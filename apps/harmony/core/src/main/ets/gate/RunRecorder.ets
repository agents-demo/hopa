import { RunRecord } from '../Types';

/** Append-only run record sink. */
export interface RunRecorder {
  record(run: RunRecord): void;
}
