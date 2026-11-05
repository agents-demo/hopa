import { RunRecord } from './Types';
import { RunRecorder } from './ActionExecutor';

/** In-memory, append-only run store. Persist it later behind the same interface. */
export class RunStore implements RunRecorder {
  private records: RunRecord[] = [];

  record(run: RunRecord): void {
    this.records.push(run);
  }

  all(): RunRecord[] {
    return this.records.slice();
  }

  clear(): void {
    this.records = [];
  }
}
