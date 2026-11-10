import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';

export class RemoteTurn {
  role: string = '';
  text: string = '';
}

export class RemoteSession {
  id: string = '';
  title: string = '';
  updated: number = 0;
  turns: RemoteTurn[] = [];
}

interface RemotePayload {
  sessions: RemoteSession[];
  updated: number;
}

/**
 * Reads the phone's conversation snapshot from the PC bridge.
 *
 * It uses the bridge's *read-only* sessions key, never the control token, and
 * it can only ever read: there is no write path here by design.
 */
export class LaptopPhoneLink {
  private static readonly NAME: string = 'hopa_laptop';
  private static readonly URL_KEY: string = 'sessions_url';
  private static readonly SECRET_KEY: string = 'sessions_key';

  url: string = '';
  key: string = '';
  sessions: RemoteSession[] = [];
  updated: number = 0;
  error: string = '';

  static async load(context: Context): Promise<LaptopPhoneLink> {
    const link = new LaptopPhoneLink();
    try {
      const store = await preferences.getPreferences(context, LaptopPhoneLink.NAME);
      const url = await store.get(LaptopPhoneLink.URL_KEY, '');
      const key = await store.get(LaptopPhoneLink.SECRET_KEY, '');
      if (typeof url === 'string') {
        link.url = url;
      }
      if (typeof key === 'string') {
        link.key = key;
      }
    } catch (error) {
      // A missing link is the normal first run.
    }
    return link;
  }

  async save(context: Context): Promise<void> {
    try {
      const store = await preferences.getPreferences(context, LaptopPhoneLink.NAME);
      await store.put(LaptopPhoneLink.URL_KEY, this.url.trim());
      await store.put(LaptopPhoneLink.SECRET_KEY, this.key.trim());
      await store.flush();
    } catch (error) {
      // Best effort; the link still works for this session.
    }
  }

  isConfigured(): boolean {
    return this.url.trim().length > 0 && this.key.trim().length > 0;
  }

  private base(): string {
    let clean: string = this.url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = `http://${clean}`;
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  async fetch(): Promise<boolean> {
    this.error = '';
    if (!this.isConfigured()) {
      this.error = 'Add the bridge address and the read-only key.';
      return false;
    }
    const client = http.createHttp();
    try {
      const response = await client.request(`${this.base()}/sessions`, {
        method: http.RequestMethod.GET,
        header: { 'Authorization': `Bearer ${this.key.trim()}` },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 15000
      });
      if (response.responseCode !== 200) {
        this.error = response.responseCode === 401
          ? 'That key was rejected.'
          : `Bridge said ${response.responseCode}.`;
        return false;
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as RemotePayload;
      this.sessions = parsed.sessions;
      this.updated = parsed.updated;
      return true;
    } catch (error) {
      this.error = 'Could not reach the bridge.';
      return false;
    } finally {
      client.destroy();
    }
  }
}
