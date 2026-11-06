import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class ReminderItem {
  id: number = 0;
  hour: number = 9;
  minute: number = 0;
  prompt: string = '';
}

class ReminderDate {
  year: number = 2026;
  month: number = 1;
  day: number = 1;
  hour: number = 9;
  minute: number = 0;
}

/**
 * One-shot reminders through the system reminder agent.
 *
 * The notification fires even when HOPA is closed; tapping it opens HOPA. HOPA
 * does not run the task in the background (HarmonyOS does not allow it), so the
 * reminder text is the deliverable.
 */
export class ReminderStore {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'reminders_v1';
  private static readonly BUNDLE: string = 'com.hopa.agent';
  private static readonly ABILITY: string = 'EntryAbility';

  private items: ReminderItem[] = [];

  all(): ReminderItem[] {
    return this.items;
  }

  async schedule(
    context: common.UIAbilityContext,
    hour: number,
    minute: number,
    prompt: string
  ): Promise<ReminderItem> {
    const date = new ReminderDate();
    const now = new Date();
    date.year = now.getFullYear();
    date.month = now.getMonth() + 1;
    date.day = now.getDate();
    date.hour = hour;
    date.minute = minute;
    if (now.getHours() > hour || (now.getHours() === hour && now.getMinutes() >= minute)) {
      const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
      date.year = tomorrow.getFullYear();
      date.month = tomorrow.getMonth() + 1;
      date.day = tomorrow.getDate();
    }

    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: date.year,
        month: date.month,
        day: date.day,
        hour: date.hour,
        minute: date.minute,
        second: 0
      },
      title: 'HOPA',
      content: prompt,
      wantAgent: {
        pkgName: ReminderStore.BUNDLE,
        abilityName: ReminderStore.ABILITY
      }
    };
    const id: number = await reminderAgentManager.publishReminder(request);
    const item = new ReminderItem();
    item.id = id;
    item.hour = hour;
    item.minute = minute;
    item.prompt = prompt;
    this.items.unshift(item);
    await this.save(context);
    return item;
  }

  async cancel(context: common.UIAbilityContext, id: number): Promise<void> {
    try {
      await reminderAgentManager.cancelReminder(id);
    } catch (error) {
      // Already fired or removed: still drop it from the list.
    }
    this.items = this.items.filter((item: ReminderItem) => item.id !== id);
    await this.save(context);
  }

  async load(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, ReminderStore.STORE);
    const raw = await store.get(ReminderStore.KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return;
    }
    try {
      this.items = JSON.parse(raw) as ReminderItem[];
    } catch (error) {
      this.items = [];
    }
  }

  private async save(context: common.UIAbilityContext): Promise<void> {
    const store = await preferences.getPreferences(context, ReminderStore.STORE);
    await store.put(ReminderStore.KEY, JSON.stringify(this.items));
    await store.flush();
  }
}
