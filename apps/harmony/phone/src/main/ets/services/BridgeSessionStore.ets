import { KeyStore } from './KeyStore';
import { BridgeSessionSink } from './BridgeClient';

export class BridgeSessionRecord {
  token: string = '';
  refresh: string = '';
}

/**
 * The paired bridge session, kept in Asset Store rather than preferences.
 *
 * The PC rotates both tokens on every pair or refresh; this class is the
 * sink the client calls when that happens, so a restart never falls back to a
 * retired token.
 */
export class BridgeSessionStore implements BridgeSessionSink {
  async save(token: string, refresh: string): Promise<void> {
    const body = new BridgeSessionRecord();
    body.token = token;
    body.refresh = refresh;
    await KeyStore.saveBridgeSession(JSON.stringify(body));
  }

  static async load(): Promise<BridgeSessionRecord> {
    const body = new BridgeSessionRecord();
    try {
      const raw: string = await KeyStore.loadBridgeSession();
      if (raw.length === 0) {
        return body;
      }
      const parsed = JSON.parse(raw) as BridgeSessionRecord;
      if (typeof parsed.token === 'string') {
        body.token = parsed.token;
      }
      if (typeof parsed.refresh === 'string') {
        body.refresh = parsed.refresh;
      }
    } catch (error) {
      // Unreadable session: the caller can fall back or re-pair.
    }
    return body;
  }

  static async clear(): Promise<void> {
    await KeyStore.clearBridgeSession();
  }
}
