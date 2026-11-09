import { ScheduleBook, ScheduledTask } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/**
 * Owns the in-app schedule, its persistence and its timer.
 *
 * The HarmonyOS reminder agent rejects this emulator, so this is an in-app
 * schedule, not a system alarm. It fires only while the process is alive.
 */
export class ScheduleService {
  readonly book: ScheduleBook = new ScheduleBook();

  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'schedules_v1';
  private static readonly TICK_MS: number = 30000;

  private context: Context | undefined = undefined;
  private timer: number = -1;
  private busy: () => boolean = () => false;
  private runner: (goal: string) => Promise<string> = async (goal: string): Promise<string> => '';

  setContext(context: Context): void {
    this.context = context;
  }

  /** The runtime tells the schedule how to run and when it is already busy. */
  bindRunner(runner: (goal: string) => Promise<string>, busy: () => boolean): void {
    this.runner = runner;
    this.busy = busy;
  }

  async load(context: Context): Promise<void> {
    this.context = context;
    try {
      const store = await preferences.getPreferences(context, ScheduleService.STORE);
      const raw = await store.get(ScheduleService.KEY, '');
      const loaded: ScheduleBook = ScheduleBook.fromJson(`${raw}`);
      for (const task of loaded.all()) {
        this.book.all().push(task);
      }
    } catch (error) {
      // First run or an unreadable store: keep the empty book.
    }
  }

  async save(): Promise<void> {
    if (this.context === undefined) {
      return;
    }
    try {
      const store = await preferences.getPreferences(this.context, ScheduleService.STORE);
      await store.put(ScheduleService.KEY, this.book.toJson());
      await store.flush();
    } catch (error) {
      // Losing a schedule edit is not worth failing the UI over.
    }
  }

  async add(goal: string, intervalMs: number, delayMs: number): Promise<boolean> {
    const task: ScheduledTask | undefined = this.book.add(goal, intervalMs, Date.now(), delayMs);
    if (task === undefined) {
      return false;
    }
    await this.save();
    return true;
  }

  async remove(id: string): Promise<void> {
    this.book.remove(id);
    await this.save();
  }

  start(): void {
    if (this.timer >= 0) {
      return;
    }
    this.timer = setInterval(() => {
      this.tick();
    }, ScheduleService.TICK_MS);
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private tick(): void {
    if (this.busy()) {
      return;
    }
    const task: ScheduledTask | undefined = this.book.nextDue(Date.now());
    if (task === undefined) {
      return;
    }
    this.book.markRan(task.id, Date.now());
    this.save().catch(() => {
      // The run matters more than the timestamp write.
    });
    this.runner(task.goal).catch(() => {
      // run() already turns failures into a transcript.
    });
  }
}
