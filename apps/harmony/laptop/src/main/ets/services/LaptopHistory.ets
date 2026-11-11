import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { LaptopTurn } from './LaptopChat';

interface StoredTurn {
  role: string;
  text: string;
}

/** Keeps the current conversation across window closes. */
export class LaptopHistory {
  private static readonly NAME: string = 'hopa_laptop';
  private static readonly KEY: string = 'turns';

  static async load(context: Context): Promise<LaptopTurn[]> {
    const turns: LaptopTurn[] = [];
    try {
      const store = await preferences.getPreferences(context, LaptopHistory.NAME);
      const raw = await store.get(LaptopHistory.KEY, '[]');
      if (typeof raw !== 'string' || raw.length === 0) {
        return turns;
      }
      const parsed = JSON.parse(raw) as StoredTurn[];
      for (const item of parsed) {
        const turn = new LaptopTurn();
        turn.role = item.role === 'assistant' ? 'assistant' : 'user';
        turn.text = item.text;
        if (turn.text.length > 0) {
          turns.push(turn);
        }
      }
    } catch (error) {
      // An unreadable history is the same as an empty one.
    }
    return turns;
  }

  static async save(context: Context, turns: LaptopTurn[]): Promise<void> {
    try {
      const stored: StoredTurn[] = [];
      for (const turn of turns) {
        const item: StoredTurn = { role: turn.role, text: turn.text };
        stored.push(item);
      }
      const store = await preferences.getPreferences(context, LaptopHistory.NAME);
      await store.put(LaptopHistory.KEY, JSON.stringify(stored));
      await store.flush();
    } catch (error) {
      // Persistence is best effort.
    }
  }
}
