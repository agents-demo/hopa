import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { ChatSync, SyncSession, SyncTurn } from '@hopa/app';
import { LaptopTurn } from './LaptopChat';

interface StoredTurn {
  role: string;
  text: string;
}

interface StoredSession {
  id: string;
  title: string;
  updated: number;
  turns: StoredTurn[];
  lastLatency?: number;
  lastTokens?: number;
}

interface StoredState {
  currentId: string;
  sessions: StoredSession[];
}

/** The wire shape the bridge and the other shell understand. */
export class SessionWireTurn {
  role: string = '';
  text: string = '';
}

export class SessionWire {
  id: string = '';
  title: string = '';
  updated: number = 0;
  turns: SessionWireTurn[] = [];
}

export class LaptopSession {
  id: string = '';
  title: string = '';
  updated: number = 0;
  turns: LaptopTurn[] = [];
  lastLatency: number = 0;
  lastTokens: number = 0;
}

/**
 * Several conversations, like the phone has, kept in preferences.
 *
 * Titles come from the first thing the user typed; nothing is invented.
 */
export class LaptopSessions {
  private static readonly NAME: string = 'hopa_laptop';
  private static readonly KEY: string = 'sessions';
  private static readonly LEGACY_KEY: string = 'turns';

  list: LaptopSession[] = [];
  currentId: string = '';
  /** The bridge is the store of record; this class is its local view. */
  private sync: ChatSync | undefined = undefined;
  private removed: string[] = [];

  attachSync(sync: ChatSync): void {
    this.sync = sync;
  }

  /** Push what this laptop has, then adopt the merged truth. */
  async syncNow(): Promise<void> {
    if (this.sync === undefined || !this.sync.isConfigured()) {
      return;
    }
    const merged: SyncSession[] = await this.sync.push(this.toSync());
    if (merged.length === 0) {
      return;
    }
    this.adopt(merged);
  }

  private toSync(): SyncSession[] {
    const out: SyncSession[] = [];
    for (const session of this.list) {
      if (session.turns.length === 0) {
        continue;
      }
      const wire = new SyncSession();
      wire.id = session.id;
      wire.title = session.title;
      wire.titleAt = session.updated;
      wire.created = session.turns.length > 0 ? session.turns[0].at : session.updated;
      wire.updated = session.updated;
      for (const turn of session.turns) {
        const item = new SyncTurn();
        item.id = turn.id;
        item.role = turn.role;
        item.text = turn.text;
        item.at = turn.at;
        wire.turns.push(item);
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
    const active: string = this.currentId;
    const kept: LaptopSession[] = [];
    for (const wire of sessions) {
      if (wire.deletedAt > 0) {
        continue;
      }
      const session = new LaptopSession();
      session.id = wire.id;
      session.title = wire.title;
      session.updated = wire.updated;
      for (const turn of wire.turns) {
        const local = new LaptopTurn();
        // Never invent an id from the position: the position moves, the id then
        // changes, and the merge sees a brand new message every time.
        local.id = turn.id;
        local.role = turn.role;
        local.text = LaptopSessions.stripMeta(turn.text);
        local.at = turn.at;
        session.turns.push(local);
      }
      kept.push(session);
    }
    if (kept.length === 0) {
      kept.push(this.create());
    }
    this.list = kept;
    let stillThere = false;
    for (const session of kept) {
      if (session.id === active) {
        stillThere = true;
        break;
      }
    }
    this.currentId = stillThere ? active : kept[0].id;
    this.removed = [];
  }

  /** The phone stores a machine block with some answers; it is not prose. */
  private static stripMeta(text: string): string {
    const lines: string[] = text.split('\n');
    const kept: string[] = [];
    for (const line of lines) {
      const trimmed: string = line.trim();
      if (trimmed.includes('[meta]') || trimmed.startsWith('shot=') || trimmed.startsWith('ref=')) {
        continue;
      }
      kept.push(line);
    }
    return kept.join('\n').trim();
  }

  /** The same shape the phone and the bridge already speak. */
  snapshot(): SessionWire[] {
    const out: SessionWire[] = [];
    for (const session of this.list) {
      if (session.turns.length === 0) {
        continue;
      }
      const wire = new SessionWire();
      wire.id = session.id;
      wire.title = session.title;
      wire.updated = session.updated;
      for (const turn of session.turns) {
        const item = new SessionWireTurn();
        item.role = turn.role;
        item.text = turn.text;
        wire.turns.push(item);
      }
      out.push(wire);
    }
    return out;
  }

  static async load(context: Context): Promise<LaptopSessions> {
    const store = new LaptopSessions();
    try {
      const prefs = await preferences.getPreferences(context, LaptopSessions.NAME);
      const raw = await prefs.get(LaptopSessions.KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        const state = JSON.parse(raw) as StoredState;
        for (const item of state.sessions) {
          store.list.push(LaptopSessions.toSession(item));
        }
        store.currentId = state.currentId;
      } else {
        // One-time migration from the single-thread history.
        const legacy = await prefs.get(LaptopSessions.LEGACY_KEY, '[]');
        if (typeof legacy === 'string' && legacy.length > 2) {
          const turns = JSON.parse(legacy) as StoredTurn[];
          const session = new LaptopSession();
          session.id = LaptopSessions.newId();
          session.turns = LaptopSessions.toTurns(turns);
          session.title = LaptopSessions.titleFor(session.turns);
          session.updated = Date.now();
          if (session.turns.length > 0) {
            store.list.push(session);
            store.currentId = session.id;
          }
        }
      }
    } catch (error) {
      // An unreadable store is an empty one.
    }
    return store;
  }

  private static toSession(item: StoredSession): LaptopSession {
    const session = new LaptopSession();
    session.id = item.id;
    session.title = item.title;
    session.updated = item.updated;
    session.turns = LaptopSessions.toTurns(item.turns);
    session.lastLatency = item.lastLatency ?? 0;
    session.lastTokens = item.lastTokens ?? 0;
    return session;
  }

  private static toTurns(items: StoredTurn[]): LaptopTurn[] {
    const turns: LaptopTurn[] = [];
    for (const item of items) {
      const turn = new LaptopTurn();
      turn.role = item.role === 'assistant' ? 'assistant' : 'user';
      // Older saves and synced phone turns can carry the machine block.
      turn.text = LaptopSessions.stripMeta(item.text);
      if (turn.text.length > 0) {
        turns.push(turn);
      }
    }
    return turns;
  }

  private static newId(): string {
    return `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
  }

  static titleFor(turns: LaptopTurn[]): string {
    for (const turn of turns) {
      if (turn.role === 'user' && turn.text.trim().length > 0) {
        const text: string = turn.text.trim().replace(/\s+/g, ' ');
        return text.length > 38 ? `${text.substring(0, 38)}…` : text;
      }
    }
    return 'New conversation';
  }

  current(): LaptopSession {
    for (const session of this.list) {
      if (session.id === this.currentId) {
        return session;
      }
    }
    return this.create();
  }

  create(): LaptopSession {
    const session = new LaptopSession();
    session.id = LaptopSessions.newId();
    session.title = 'New conversation';
    session.updated = Date.now();
    this.list.unshift(session);
    this.currentId = session.id;
    return session;
  }

  select(id: string): void {
    this.currentId = id;
  }

  /** A delete is a tombstone for the bridge, so it cannot come back. */
  removeEverywhere(id: string): void {
    this.removed.push(id);
    this.remove(id);
  }

  remove(id: string): void {
    const kept: LaptopSession[] = [];
    for (const session of this.list) {
      if (session.id !== id) {
        kept.push(session);
      }
    }
    this.list = kept;
    if (this.currentId === id) {
      this.currentId = this.list.length > 0 ? this.list[0].id : '';
    }
  }

  /** At most one blank draft: repeated New chat must not stack them. */
  prune(): void {
    const kept: LaptopSession[] = [];
    let keptEmpty: boolean = false;
    for (const session of this.list) {
      if (session.turns.length === 0) {
        if (keptEmpty) {
          continue;
        }
        keptEmpty = true;
      }
      kept.push(session);
    }
    this.list = kept;
    let found: boolean = false;
    for (const session of this.list) {
      if (session.id === this.currentId) {
        found = true;
        break;
      }
    }
    if (!found) {
      this.currentId = this.list.length > 0 ? this.list[0].id : '';
    }
  }

  /** Called after a reply: the thread owns its turns and its title. */
  commit(turns: LaptopTurn[], latency: number, tokens: number): void {
    const session = this.current();
    session.turns = turns.slice();
    session.title = LaptopSessions.titleFor(turns);
    session.updated = Date.now();
    session.lastLatency = latency;
    session.lastTokens = tokens;
  }

  async save(context: Context): Promise<void> {
    try {
      const state: StoredState = { currentId: this.currentId, sessions: [] };
      for (const session of this.list) {
        const turns: StoredTurn[] = [];
        for (const turn of session.turns) {
          const item: StoredTurn = { role: turn.role, text: turn.text };
          turns.push(item);
        }
        const stored: StoredSession = {
          id: session.id,
          title: session.title,
          updated: session.updated,
          turns: turns
        };
        stored.lastLatency = session.lastLatency;
        stored.lastTokens = session.lastTokens;
        state.sessions.push(stored);
      }
      const prefs = await preferences.getPreferences(context, LaptopSessions.NAME);
      await prefs.put(LaptopSessions.KEY, JSON.stringify(state));
      await prefs.flush();
    } catch (error) {
      // Persistence is best effort.
    }
  }
}
