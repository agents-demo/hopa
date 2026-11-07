import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class MemoryItem {
  id: string = '';
  text: string = '';
  createdAt: number = 0;
}

/**
 * Small on-device memory of explicit facts the user asked HOPA to keep.
 *
 * Only user-authored text is stored: no screen content, no model guesses.
 * Items are injected into the system prompt and are visible and deletable in
 * the Memory tab.
 */
export class MemoryStore {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'memory_v1';
  private static readonly LIMIT: number = 50;

  private items: MemoryItem[] = [];

  all(): MemoryItem[] {
    return this.items;
  }

  add(text: string): MemoryItem | undefined {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    const item = new MemoryItem();
    item.id = `m-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    item.text = trimmed.length > 500 ? trimmed.substring(0, 500) : trimmed;
    item.createdAt = Date.now();
    this.items.unshift(item);
    if (this.items.length > MemoryStore.LIMIT) {
      this.items = this.items.slice(0, MemoryStore.LIMIT);
    }
    return item;
  }

  remove(id: string): boolean {
    const before: number = this.items.length;
    this.items = this.items.filter((item: MemoryItem) => item.id !== id);
    return this.items.length !== before;
  }

  clear(): void {
    this.items = [];
  }

  /** The block added to the system prompt. Empty when there is no memory. */
  toPrompt(): string {
    if (this.items.length === 0) {
      return '';
    }
    const lines: string[] = [];
    for (const item of this.items) {
      lines.push(`- ${item.text}`);
    }
    return `Things the user asked you to remember:\n${lines.join('\n')}`;
  }

  async load(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, MemoryStore.STORE);
    const raw = await store.get(MemoryStore.KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as MemoryItem[];
      this.items = parsed.filter((item: MemoryItem) => item.text.length > 0);
    } catch (error) {
      this.items = [];
    }
  }

  async save(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, MemoryStore.STORE);
    await store.put(MemoryStore.KEY, JSON.stringify(this.items));
    await store.flush();
  }
}
