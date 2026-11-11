import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';

/**
 * The conversation sync client.
 *
 * The PC bridge keeps the one conversation store; this speaks to it. Pull takes
 * everything the store knows, push hands it whatever this device has. Both are
 * merges on the bridge, so calling them in either order is safe — a message is
 * identified by its id and a device can never overwrite another's turn.
 */

export class SyncTurn {
  id: string = '';
  role: string = '';
  text: string = '';
  at: number = 0;
}

export class SyncSession {
  id: string = '';
  title: string = '';
  titleAt: number = 0;
  created: number = 0;
  updated: number = 0;
  /** Non-zero means deleted: a tombstone, so an old copy cannot revive it. */
  deletedAt: number = 0;
  turns: SyncTurn[] = [];
}

class SyncAnswer {
  rev: number = 0;
  sessions: SyncSession[] = [];
}

class SyncPushBody {
  sessions: SyncSession[] = [];
}

class SyncUrls {
  url: string = '';
  token: string = '';
  role: string = '';
}

class ImageReceipt {
  id: string = '';
  mime: string = '';
  bytes: number = 0;
}

class ImageUpload {
  mime: string = '';
  data: string = '';
}

export class ChatSync {
  private where: SyncUrls = new SyncUrls();

  configure(url: string, token: string, role: string): void {
    let clean: string = url.trim();
    if (clean.length > 0 && !clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = `http://${clean}`;
    }
    clean = clean.replace('://localhost', '://127.0.0.1');
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    this.where.url = clean;
    this.where.token = token.trim();
    this.where.role = role.trim();
  }

  isConfigured(): boolean {
    return this.where.url.length > 0 && this.where.token.length > 0;
  }

  private headers(): Record<string, string> {
    const header: Record<string, string> = {
      'Authorization': `Bearer ${this.where.token}`
    };
    if (this.where.role.length > 0) {
      header['X-Hopa-Role'] = this.where.role;
    }
    return header;
  }

  /** Everything the store knows, newest first. */
  async pull(): Promise<SyncSession[]> {
    if (!this.isConfigured()) {
      return [];
    }
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.where.url}/chats`, {
        method: http.RequestMethod.GET,
        header: this.headers(),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        return [];
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as SyncAnswer;
      return parsed.sessions;
    } catch (error) {
      return [];
    } finally {
      client.destroy();
    }
  }

  /** Hand the store this device's sessions; the answer is the merged truth. */
  async push(sessions: SyncSession[]): Promise<SyncSession[]> {    if (!this.isConfigured()) {
      return [];
    }
    const body = new SyncPushBody();
    body.sessions = sessions;
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.where.url}/chats`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.where.token}`,
          'X-Hopa-Role': this.where.role
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        return [];
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as SyncAnswer;
      return parsed.sessions;
    } catch (error) {
      return [];
    } finally {
      client.destroy();
    }
  }

  /**
   * Put a frame in the shared store and return its id.
   *
   * The id is what a turn carries, because a sandbox path means nothing on the
   * other device; the bytes live once on the PC and both shells read them.
   */
  async uploadImage(dataBase64: string, mime: string): Promise<string> {
    if (!this.isConfigured() || dataBase64.length === 0) {
      return '';
    }
    const body = new ImageUpload();
    body.mime = mime;
    body.data = dataBase64;
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.where.url}/images`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.where.token}`,
          'X-Hopa-Role': this.where.role
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        return '';
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      return (JSON.parse(raw) as ImageReceipt).id;
    } catch (error) {
      return '';
    } finally {
      client.destroy();
    }
  }

  /** Read a frame the other device uploaded; undefined when it is not there. */
  async downloadImage(id: string): Promise<ArrayBuffer | undefined> {
    if (!this.isConfigured() || id.length === 0) {
      return undefined;
    }
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.where.url}/images/${id}`, {
        method: http.RequestMethod.GET,
        header: this.headers(),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        return undefined;
      }
      return response.result as ArrayBuffer;
    } catch (error) {
      return undefined;
    } finally {
      client.destroy();
    }
  }
}
