/**
 * Saved conversations.
 *
 * The Chat screen used to keep one in-memory transcript. The drawer keeps a
 * list of conversations; this is the same idea without moving message
 * rendering out of the page: the page turns entries back into its message list.
 */
export class ChatEntry {
  /** Stable identity across devices: the sync merges by this, not by text. */
  id: string = '';
  role: string = '';
  text: string = '';
  at: number = 0;
}

export class ChatSession {
  id: string = '';
  title: string = '';
  entries: ChatEntry[] = [];
  updatedAt: number = 0;
}

class ChatPayload {
  sessions: ChatSession[] = [];
  currentId: string = '';
  counter: number = 0;
}

export class ChatHistory {
  private sessions: ChatSession[] = [];
  private activeId: string = '';
  private counter: number = 0;

  all(): ChatSession[] {
    return this.sessions;
  }

  currentId(): string {
    return this.activeId;
  }

  current(): ChatSession | undefined {
    for (const session of this.sessions) {
      if (session.id === this.activeId) {
        return session;
      }
    }
    return undefined;
  }

  /** Creates the first conversation when the app has never saved one. */
  ensureCurrent(now: number): ChatSession {
    const existing: ChatSession | undefined = this.current();
    if (existing !== undefined) {
      return existing;
    }
    return this.newSession(now);
  }

  newSession(now: number): ChatSession {
    this.counter += 1;
    const session = new ChatSession();
    session.id = `c-${now}-${this.counter}`;
    session.title = 'New chat';
    session.updatedAt = now;
    this.sessions.unshift(session);
    this.activeId = session.id;
    return session;
  }

  select(id: string): boolean {
    for (const session of this.sessions) {
      if (session.id === id) {
        this.activeId = id;
        return true;
      }
    }
    return false;
  }

  remove(id: string): boolean {
    const kept: ChatSession[] = [];
    for (const session of this.sessions) {
      if (session.id !== id) {
        kept.push(session);
      }
    }
    const changed: boolean = kept.length < this.sessions.length;
    this.sessions = kept;
    if (changed && this.activeId === id) {
      this.activeId = this.sessions.length > 0 ? this.sessions[0].id : '';
    }
    return changed;
  }

  /** Appends to the active conversation and derives its title from the first question. */
  add(role: string, text: string, now: number): boolean {
    const trimmed: string = text.trim();
    if (trimmed.length === 0) {
      return false;
    }
    const session: ChatSession = this.ensureCurrent(now);
    const entry = new ChatEntry();
    this.counter += 1;
    entry.id = `${session.id}·${this.counter}·${now}`;
    entry.role = role;
    entry.text = trimmed;
    entry.at = now;
    session.entries.push(entry);
    session.updatedAt = now;
    if (role === 'user' && (session.title === 'New chat' || session.title.length === 0)) {
      session.title = trimmed.length > 40 ? `${trimmed.substring(0, 40)}...` : trimmed;
      this.sortByUpdated();
    }
    return true;
  }

  private sortByUpdated(): void {
    const active: ChatSession | undefined = this.current();
    const others: ChatSession[] = [];
    for (const session of this.sessions) {
      if (session.id !== this.activeId) {
        others.push(session);
      }
    }
    others.sort((left: ChatSession, right: ChatSession) => right.updatedAt - left.updatedAt);
    if (active !== undefined) {
      others.unshift(active);
    }
    this.sessions = others;
  }

  toJson(): string {
    const payload = new ChatPayload();
    payload.sessions = this.sessions;
    payload.currentId = this.activeId;
    payload.counter = this.counter;
    return JSON.stringify(payload);
  }

  static fromJson(raw: string): ChatHistory {
    const history = new ChatHistory();
    if (raw.length === 0) {
      return history;
    }
    try {
      const payload = JSON.parse(raw) as ChatPayload;
      if (payload.sessions !== undefined) {
        const restored: ChatSession[] = [];
        for (const saved of payload.sessions) {
          // JSON loses methods, so rebuild real instances.
          const session = new ChatSession();
          session.id = saved.id;
          session.title = saved.title;
          session.updatedAt = saved.updatedAt;
          const entries: ChatEntry[] = [];
          for (let index = 0; index < (saved.entries === undefined ? 0 : saved.entries.length); index++) {
            const savedEntry = (saved.entries as ChatEntry[])[index];
            const entry = new ChatEntry();
            // Older saves have no ids: derive one so a merge stays stable.
            entry.id = savedEntry.id !== undefined && savedEntry.id.length > 0
              ? savedEntry.id
              : `${saved.id}·${index}`;
            entry.role = savedEntry.role;
            entry.text = savedEntry.text;
            entry.at = savedEntry.at !== undefined ? savedEntry.at : saved.updatedAt;
            entries.push(entry);
          }
          session.entries = entries;
          restored.push(session);
        }
        history.sessions = restored;
      }
      if (payload.currentId !== undefined) {
        history.activeId = payload.currentId;
      }
      if (payload.counter !== undefined) {
        history.counter = payload.counter;
      }
    } catch (error) {
      return new ChatHistory();
    }
    return history;
  }
}
