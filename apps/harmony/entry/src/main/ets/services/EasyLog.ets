import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/** One thing an Easy user asked, and what HOPA answered. */
export class EasyEntry {
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
export class EasyLog {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'easy_log_v1';
  private static entries: EasyEntry[] = [];
  private static loaded: boolean = false;

  static async load(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, EasyLog.STORE);
      const raw = await store.get(EasyLog.KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed = JSON.parse(raw) as EasyEntry[];
        EasyLog.entries = Array.isArray(parsed) ? parsed : [];
      }
    } catch (error) {
      EasyLog.entries = [];
    }
    EasyLog.loaded = true;
  }

  static all(): EasyEntry[] {
    return EasyLog.entries;
  }

  static async add(context: Context, goal: string, answer: string): Promise<void> {
    if (!EasyLog.loaded) {
      await EasyLog.load(context);
    }
    const entry = new EasyEntry();
    entry.goal = goal;
    entry.answer = answer;
    entry.at = Date.now();
    EasyLog.entries = [entry].concat(EasyLog.entries).slice(0, 30);
    try {
      const store = await preferences.getPreferences(context, EasyLog.STORE);
      await store.put(EasyLog.KEY, JSON.stringify(EasyLog.entries));
      await store.flush();
    } catch (error) {
      // The in-memory list still serves this session.
    }
  }

  static async clear(context: Context): Promise<void> {
    EasyLog.entries = [];
    try {
      const store = await preferences.getPreferences(context, EasyLog.STORE);
      await store.put(EasyLog.KEY, '[]');
      await store.flush();
    } catch (error) {
      // Best effort.
    }
  }
}
