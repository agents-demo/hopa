import { ChatEntry, ChatHistory, ChatSession } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

/**
 * Owns the saved conversations and their persistence.
 *
 * The Chats sheet and the chat page share this one instance; `version` lets
 * the chat page notice a change made from the sheet.
 */
export class ConversationService {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'chats_v1';

  private history: ChatHistory = new ChatHistory();
  private context: Context | undefined = undefined;
  private loaded: boolean = false;

  version: number = 0;

  async load(context: Context): Promise<void> {
    this.context = context;
    if (this.loaded) {
      return;
    }
    try {
      const store = await preferences.getPreferences(context, ConversationService.STORE);
      const raw = await store.get(ConversationService.KEY, '');
      this.history = ChatHistory.fromJson(`${raw}`);
    } catch (error) {
      this.history = new ChatHistory();
    }
    this.history.ensureCurrent(Date.now());
    this.loaded = true;
    this.version += 1;
    await this.save();
  }

  async save(): Promise<void> {
    if (this.context === undefined) {
      return;
    }
    try {
      const store = await preferences.getPreferences(this.context, ConversationService.STORE);
      await store.put(ConversationService.KEY, this.history.toJson());
      await store.flush();
    } catch (error) {
      // History is best effort; the session still works in memory.
    }
  }

  all(): ChatSession[] {
    return this.history.all();
  }

  currentId(): string {
    return this.history.currentId();
  }

  current(): ChatSession | undefined {
    return this.history.current();
  }

  entries(): ChatEntry[] {
    const session: ChatSession | undefined = this.history.current();
    return session === undefined ? [] : session.entries;
  }

  newChat(): void {
    this.history.newSession(Date.now());
    this.version += 1;
    this.save();
  }

  select(id: string): boolean {
    const changed: boolean = this.history.select(id);
    if (changed) {
      this.version += 1;
    }
    return changed;
  }

  delete(id: string): void {
    this.history.remove(id);
    this.history.ensureCurrent(Date.now());
    this.version += 1;
    this.save();
  }

  add(role: string, text: string): void {
    if (this.history.add(role, text, Date.now())) {
      this.version += 1;
      this.save();
    }
  }
}
