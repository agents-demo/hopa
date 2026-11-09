import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** One thing an Easy user asked, and what HOPA answered. */
export class TaskLogEntry {
  goal: string = '';
  answer: string = '';
  at: number = 0;
}

/**
 * A simple, persistent log for Easy mode.
 *
 * Easy runs do not create chat sessions (that was the point), so this is the
 * user's history: goal, answer, time — newest first, capped at 30.
 */
export class TaskLog {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'easy_log_v1';
  private static entries: TaskLogEntry[] = [];
  private static loaded: boolean = false;

  static async load(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, TaskLog.STORE);
      const raw = await store.get(TaskLog.KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed = JSON.parse(raw) as TaskLogEntry[];
        TaskLog.entries = Array.isArray(parsed) ? parsed : [];
      }
    } catch (error) {
      TaskLog.entries = [];
    }
    TaskLog.loaded = true;
  }

  static all(): TaskLogEntry[] {
    return TaskLog.entries;
  }

  static async add(context: Context, goal: string, answer: string): Promise<void> {
    if (!TaskLog.loaded) {
      await TaskLog.load(context);
    }
    const entry = new TaskLogEntry();
    entry.goal = goal;
    entry.answer = answer;
    entry.at = Date.now();
    TaskLog.entries = [entry].concat(TaskLog.entries).slice(0, 30);
    try {
      const store = await preferences.getPreferences(context, TaskLog.STORE);
      await store.put(TaskLog.KEY, JSON.stringify(TaskLog.entries));
      await store.flush();
    } catch (error) {
      // The in-memory list still serves this session.
    }
  }

  static async clear(context: Context): Promise<void> {
    TaskLog.entries = [];
    try {
      const store = await preferences.getPreferences(context, TaskLog.STORE);
      await store.put(TaskLog.KEY, '[]');
      await store.flush();
    } catch (error) {
      // Best effort.
    }
  }
}
