import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';
import { AgentService } from './AgentService';

/** One turn of a read-only conversation that lives on the laptop. */
export class LaptopTurnView {
  role: string = '';
  text: string = '';
}

/** The laptop's thread as the phone sees it: no editing, no merge. */
export class LaptopSessionView {
  id: string = '';
  title: string = '';
  updated: number = 0;
  turns: LaptopTurnView[] = [];
}

interface LaptopPayload {
  sessions: LaptopSessionView[];
  updated: number;
}

/**
 * Reads the laptop's conversations from the same bridge the phone uses.
 *
 * It presents the phone's own token and asks the pool for the `2in1` device,
 * so the phone never needs the laptop's secret. Nothing here writes.
 */
export class LaptopLink {
  sessions: LaptopSessionView[] = [];
  error: string = '';

  async fetch(): Promise<boolean> {
    this.error = '';
    const bridge = AgentService.get().bridge;
    if (!bridge.isConfigured()) {
      this.sessions = [];
      return false;
    }
    const client = http.createHttp();
    try {
      const response = await client.request(`${bridge.endpoint()}/sessions`, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${bridge.authToken()}`,
          'X-Hopa-Role': 'phone',
          'X-Hopa-Read': '2in1'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 6000,
        readTimeout: 15000
      });
      if (response.responseCode !== 200) {
        this.error = response.responseCode === 401
          ? 'That bridge key was rejected.'
          : `Bridge said ${response.responseCode}.`;
        return false;
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as LaptopPayload;
      const withTurns: LaptopSessionView[] = [];
      for (const session of parsed.sessions) {
        if (session.turns.length > 0) {
          withTurns.push(session);
        }
      }
      withTurns.sort((a: LaptopSessionView, b: LaptopSessionView) => b.updated - a.updated);
      this.sessions = withTurns;
      return true;
    } catch (error) {
      this.error = 'Could not reach the bridge.';
      return false;
    } finally {
      client.destroy();
    }
  }
}
