import { ChatEntry, ChatHistory, ChatSession } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ChatSync, SyncSession, SyncTurn } from './ChatSync';

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
  /** The host decides who cares; the kit just reports a change. */
  private changeListener: (() => void) | undefined = undefined;

  setChangeListener(listener: () => void): void {
    this.changeListener = listener;
  }

  private notify(): void {
    if (this.changeListener !== undefined) {
      this.changeListener();
    }
  }
  private context: Context | undefined = undefined;
  private loaded: boolean = false;
  /** The bridge is the store of record; without it this is a local cache. */
  private sync: ChatSync | undefined = undefined;
  private syncTimer: number = -1;
  /** Guards the loop: adopting a merge is not a user edit. */
  private syncing: boolean = false;
  private removed: string[] = [];

  version: number = 0;

  attachSync(sync: ChatSync): void {
    this.sync = sync;
  }

  /** Push what this device has, then adopt the merged truth. */
  async syncNow(): Promise<void> {
    if (this.sync === undefined || !this.sync.isConfigured() || this.syncing) {
      return;
    }
    this.syncing = true;
    try {
      const before: string = this.history.toJson();
      const merged: SyncSession[] = await this.sync.push(this.toSync());
      if (merged.length === 0) {
        return;
      }
      this.adopt(merged);
      await this.save();
      if (this.history.toJson() !== before) {
        this.notify();
      }
    } finally {
      this.syncing = false;
    }
  }

  /** Coalesce bursts of edits into one exchange with the bridge. */
  private scheduleSync(): void {
    if (this.sync === undefined || !this.sync.isConfigured() || this.syncing) {
      return;
    }
    if (this.syncTimer >= 0) {
      clearTimeout(this.syncTimer);
    }
    this.syncTimer = setTimeout(() => {
      this.syncTimer = -1;
      this.syncNow();
    }, 1200);
  }

  private toSync(): SyncSession[] {
    const out: SyncSession[] = [];
    for (const session of this.history.all()) {
      if (session.entries.length === 0 && session.title === 'New chat') {
        // An empty draft is not history.
        continue;
      }
      const wire = new SyncSession();
      wire.id = session.id;
      wire.title = session.title;
      wire.titleAt = session.updatedAt;
      wire.created = session.entries.length > 0 ? session.entries[0].at : session.updatedAt;
      wire.updated = session.updatedAt;
      for (const entry of session.entries) {
        const turn = new SyncTurn();
        turn.id = entry.id;
        turn.role = entry.role;
        turn.text = entry.text;
        turn.at = entry.at;
        wire.turns.push(turn);
      }
      out.push(wire);
    }
    for (const id of this.removed) {
      const grave = new SyncSession();
      grave.id = id;
      grave.deletedAt = Date.now();
      out.push(grave);
    }
    return out;
  }

  private adopt(sessions: SyncSession[]): void {
    const active: string = this.history.currentId();
    const kept: ChatSession[] = [];
    for (const wire of sessions) {
      if (wire.deletedAt > 0) {
        continue;
      }
      const session = new ChatSession();
      session.id = wire.id;
      session.title = wire.title;
      session.updatedAt = wire.updated;
      const entries: ChatEntry[] = [];
      for (const turn of wire.turns) {
        const entry = new ChatEntry();
        entry.id = turn.id;
        entry.role = turn.role;
        entry.text = turn.text;
        entry.at = turn.at;
        entries.push(entry);
      }
      session.entries = entries;
      kept.push(session);
    }
    if (kept.length === 0) {
      kept.push(this.history.ensureCurrent(Date.now()));
    }
    let stillThere = false;
    for (const session of kept) {
      if (session.id === active) {
        stillThere = true;
        break;
      }
    }
    if (!stillThere) {
      this.history.select(kept[0].id);
    }
    const rebuilt = ChatHistory.fromJson(JSON.stringify({
      sessions: kept,
      currentId: stillThere ? active : kept[0].id,
      counter: kept.length
    }));
    this.history = rebuilt;
    this.removed = [];
    this.version += 1;
  }

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
    this.pruneEmpty();
    this.loaded = true;
    this.version += 1;
    await this.save();
    // The bridge may know threads this device has never seen.
    await this.syncNow();
    // Listeners (the session relay) only care once the store is real; a push
    // that starts before this line would send an empty snapshot.
    this.notify();
  }

  /** Removing a thread is a tombstone for the bridge, not a local forgetting. */
  deleteEverywhere(id: string): void {
    this.removed.push(id);
    this.history.remove(id);
    this.version += 1;
    this.save();
    this.notify();
    this.scheduleSync();
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
    const current: ChatSession | undefined = this.history.current();
    if (current !== undefined && current.entries.length === 0) {
      // An empty draft is already open: reuse it instead of stacking another.
      this.notify();
      return;
    }
    this.history.newSession(Date.now());
    this.version += 1;
    this.save();
    this.notify();
  }

  /** A chat with no messages is not history: keep only the open draft. */
  private pruneEmpty(): void {
    const currentId: string = this.history.currentId();
    const empties: string[] = [];
    for (const session of this.history.all()) {
      if (session.entries.length === 0 && session.id !== currentId) {
        empties.push(session.id);
      }
    }
    for (const id of empties) {
      this.history.remove(id);
    }
    this.history.ensureCurrent(Date.now());
  }

  select(id: string): boolean {
    const changed: boolean = this.history.select(id);
    if (changed) {
      this.version += 1;
      this.notify();
    }
    return changed;
  }

  delete(id: string): void {
    this.history.remove(id);
    this.history.ensureCurrent(Date.now());
    this.version += 1;
    this.save();
    this.notify();
  }

  add(role: string, text: string): void {
    if (this.history.add(role, text, Date.now())) {
      this.version += 1;
      this.save();
      this.notify();
    }
  }
}
