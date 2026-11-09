import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class LogEntry {
  at: number = 0;
  message: string = '';
}

/**
 * A small on-device ring of recent failures.
 *
 * No telemetry: the user can read and clear it in Settings. Used for model,
 * bridge and run failures so a broken setup is diagnosable without a PC log.
 */
export class ErrorLog {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'error_log_v1';
  private static entries: LogEntry[] = [];
  private static loaded: boolean = false;

  static async load(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, ErrorLog.STORE);
      const raw = await store.get(ErrorLog.KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        const parsed = JSON.parse(raw) as LogEntry[];
        ErrorLog.entries = Array.isArray(parsed) ? parsed : [];
      }
    } catch (error) {
      ErrorLog.entries = [];
    }
    ErrorLog.loaded = true;
  }

  static all(): LogEntry[] {
    return ErrorLog.entries;
  }

  static async record(context: Context, message: string): Promise<void> {
    if (!ErrorLog.loaded) {
      await ErrorLog.load(context);
    }
    const text: string = message.trim();
    if (text.length === 0) {
      return;
    }
    const entry = new LogEntry();
    entry.at = Date.now();
    entry.message = text.length > 400 ? `${text.substring(0, 400)}…` : text;
    ErrorLog.entries = [entry].concat(ErrorLog.entries).slice(0, 30);
    try {
      const store = await preferences.getPreferences(context, ErrorLog.STORE);
      await store.put(ErrorLog.KEY, JSON.stringify(ErrorLog.entries));
      await store.flush();
    } catch (error) {
      // The in-memory list still shows in this session.
    }
  }

  static async clear(context: Context): Promise<void> {
    ErrorLog.entries = [];
    try {
      const store = await preferences.getPreferences(context, ErrorLog.STORE);
      await store.put(ErrorLog.KEY, '[]');
      await store.flush();
    } catch (error) {
      // Best effort.
    }
  }
}
