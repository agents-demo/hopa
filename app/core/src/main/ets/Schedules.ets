/**
 * In-app scheduled goals.
 *
 * The HarmonyOS reminder agent rejects this emulator (`1700002`), so the app
 * keeps its own schedule and fires due goals while the HOPA process is alive.
 * A one-shot task disables itself after it runs; a repeating task moves its
 * next run forward. Persistence is the caller's job.
 */
export class ScheduledTask {
  id: string = '';
  goal: string = '';
  /** 0 means one-shot; otherwise the repeat interval in milliseconds. */
  intervalMs: number = 0;
  nextRunAt: number = 0;
  lastRunAt: number = 0;
  enabled: boolean = true;

  isRepeating(): boolean {
    return this.intervalMs > 0;
  }

  label(): string {
    if (!this.isRepeating()) {
      return 'once';
    }
    const minutes: number = Math.round(this.intervalMs / 60000);
    if (minutes >= 60 * 24) {
      return 'daily';
    }
    return `every ${minutes} min`;
  }
}

class SchedulePayload {
  items: ScheduledTask[] = [];
  counter: number = 0;
}

export class ScheduleBook {
  private items: ScheduledTask[] = [];
  private counter: number = 0;

  all(): ScheduledTask[] {
    return this.items;
  }

  size(): number {
    return this.items.length;
  }

  add(goal: string, intervalMs: number, now: number, delayMs: number = 0): ScheduledTask | undefined {
    const trimmed: string = goal.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    this.counter += 1;
    const task = new ScheduledTask();
    task.id = `s-${now}-${this.counter}`;
    task.goal = trimmed;
    task.intervalMs = intervalMs > 0 ? intervalMs : 0;
    task.nextRunAt = now + (delayMs > 0 ? delayMs : intervalMs);
    task.enabled = true;
    this.items.push(task);
    return task;
  }

  remove(id: string): boolean {
    const before: number = this.items.length;
    const kept: ScheduledTask[] = [];
    for (const item of this.items) {
      if (item.id !== id) {
        kept.push(item);
      }
    }
    this.items = kept;
    return this.items.length < before;
  }

  setEnabled(id: string, enabled: boolean, now: number): void {
    for (const item of this.items) {
      if (item.id === id) {
        item.enabled = enabled;
        if (enabled) {
          item.nextRunAt = now + (item.intervalMs > 0 ? item.intervalMs : 60000);
        }
      }
    }
  }

  /** The first enabled task whose time has come. */
  nextDue(now: number): ScheduledTask | undefined {
    for (const item of this.items) {
      if (item.enabled && item.nextRunAt <= now) {
        return item;
      }
    }
    return undefined;
  }

  markRan(id: string, now: number): void {
    for (const item of this.items) {
      if (item.id !== id) {
        continue;
      }
      item.lastRunAt = now;
      if (item.isRepeating()) {
        item.nextRunAt = now + item.intervalMs;
      } else {
        item.enabled = false;
      }
    }
  }

  /** Milliseconds until the next enabled task, or -1 when nothing is due. */
  nextDueInMs(now: number): number {
    let best: number = -1;
    for (const item of this.items) {
      if (!item.enabled) {
        continue;
      }
      const delta: number = item.nextRunAt - now;
      if (best < 0 || delta < best) {
        best = delta;
      }
    }
    return best;
  }

  toJson(): string {
    const payload = new SchedulePayload();
    payload.items = this.items;
    payload.counter = this.counter;
    return JSON.stringify(payload);
  }

  static fromJson(raw: string): ScheduleBook {
    const book = new ScheduleBook();
    if (raw.length === 0) {
      return book;
    }
    try {
      const payload = JSON.parse(raw) as SchedulePayload;
      if (payload.items !== undefined) {
        book.items = payload.items;
      }
      if (payload.counter !== undefined) {
        book.counter = payload.counter;
      }
    } catch (error) {
      return book;
    }
    return book;
  }
}
