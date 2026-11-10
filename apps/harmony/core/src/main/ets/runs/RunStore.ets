import { RunRecord } from '../Types';
import { RunRecorder } from '../gate/RunRecorder';

/** In-memory, append-only run store. Persist it later behind the same interface. */
export class RunStore implements RunRecorder {
  private records: RunRecord[] = [];

  record(run: RunRecord): void {
    this.records.push(run);
  }

  all(): RunRecord[] {
    return this.records.slice();
  }

  /** Attaches a step thumbnail to an existing record. */
  attachShot(id: string, shot: string): boolean {
    for (const run of this.records) {
      if (run.id === id) {
        run.shot = shot;
        return true;
      }
    }
    return false;
  }

  /** Replaces the store from persisted records (startup restore). */
  replace(records: RunRecord[]): void {
    this.records = records.slice();
  }

  clear(): void {
    this.records = [];
  }
}
