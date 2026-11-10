import { RunRecord, RunStore } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** Persists the last 100 run records; history is capped, not infinite. */
export class RunArchive {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'runs_v1';

  private runs: RunStore;

  constructor(runs: RunStore) {
    this.runs = runs;
  }

  async load(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, RunArchive.STORE);
    const raw = await store.get(RunArchive.KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as RunRecord[];
      for (const run of parsed) {
        if (typeof run.shot !== 'string') {
          run.shot = '';
        }
        if (typeof run.turnId !== 'string') {
          run.turnId = '';
        }
        if (typeof run.changed !== 'string') {
          run.changed = '';
        }
        if (typeof run.verified !== 'boolean') {
          run.verified = false;
        }
      }
      this.runs.replace(parsed);
    } catch (error) {
      // Unreadable history: keep the empty store.
    }
  }

  async save(context: Context): Promise<void> {
    const all: RunRecord[] = this.runs.all();
    const recent: RunRecord[] = all.length > 100 ? all.slice(all.length - 100) : all;
    const store = await preferences.getPreferences(context, RunArchive.STORE);
    await store.put(RunArchive.KEY, JSON.stringify(recent));
    await store.flush();
  }
}
