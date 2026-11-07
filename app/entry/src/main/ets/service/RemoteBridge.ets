import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';

export class RemoteNode {
  ref: string = '';
  text: string = '';
  description: string = '';
  type: string = '';
  bounds: number[] = [];
  clickable: boolean = false;
}

class RemoteObservationBody {
  text: string = '';
  nodes: RemoteNode[] = [];
  width: number = 0;
  height: number = 0;
}

class RemoteOkBody {
  ok: boolean = false;
}

/**
 * Client for `pc-agent bridge`.
 *
 * The phone asks the PC for the current layout and sends taps/types/launches
 * back. The token stays in memory only.
 */
export class RemoteBridge {
  private baseUrl: string = '';
  private token: string = '';
  private lastText: string = '';
  private lastNodes: RemoteNode[] = [];
  private width: number = 0;
  private height: number = 0;
  private lastError: string = '';

  configure(url: string, token: string): void {
    let clean: string = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    this.baseUrl = clean;
    this.token = token.trim();
  }

  isConfigured(): boolean {
    return this.baseUrl.length > 0 && this.token.length > 0;
  }

  lastPageText(): string {
    return this.lastText;
  }

  lastFailure(): string {
    return this.lastError;
  }

  private async call(path: string, payload: string): Promise<string> {
    if (!this.isConfigured()) {
      throw new Error('bridge is not configured');
    }
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.token}`
        },
        extraData: payload,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 45000
      };
      const response = await client.request(`${this.baseUrl}${path}`, options);
      if (response.responseCode !== 200) {
        throw new Error(`bridge HTTP ${response.responseCode}`);
      }
      return buffer.from(response.result as ArrayBuffer).toString('utf8');
    } finally {
      client.destroy();
    }
  }

  private async get(path: string): Promise<string> {
    if (!this.isConfigured()) {
      throw new Error('bridge is not configured');
    }
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${this.token}`
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 20000
      };
      const response = await client.request(`${this.baseUrl}${path}`, options);
      if (response.responseCode !== 200) {
        throw new Error(`bridge HTTP ${response.responseCode}`);
      }
      return buffer.from(response.result as ArrayBuffer).toString('utf8');
    } finally {
      client.destroy();
    }
  }

  async health(): Promise<boolean> {
    try {
      const raw: string = await this.get('/health');
      const parsed = JSON.parse(raw) as RemoteOkBody;
      this.lastError = parsed.ok ? '' : 'bridge said not ok';
      return parsed.ok;
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return false;
    }
  }

  async observe(): Promise<boolean> {
    try {
      const raw: string = await this.call('/observe', '{}');
      const parsed = JSON.parse(raw) as RemoteObservationBody;
      this.lastText = parsed.text;
      this.lastNodes = parsed.nodes;
      this.width = parsed.width;
      this.height = parsed.height;
      return true;
    } catch (error) {
      return false;
    }
  }

  boundsFor(ref: string): number[] {
    for (const node of this.lastNodes) {
      if (node.ref === ref) {
        return node.bounds;
      }
    }
    return [];
  }

  nodes(): RemoteNode[] {
    return this.lastNodes;
  }

  screenWidth(): number {
    return this.width;
  }

  screenHeight(): number {
    return this.height;
  }

  async tap(x: number, y: number): Promise<boolean> {
    try {
      await this.call('/tap', JSON.stringify({ x: x, y: y }));
      return true;
    } catch (error) {
      return false;
    }
  }

  async typeText(text: string, x: number, y: number): Promise<boolean> {
    try {
      await this.call('/type', JSON.stringify({ text: text, x: x, y: y }));
      return true;
    } catch (error) {
      return false;
    }
  }

  async launch(bundle: string): Promise<boolean> {
    try {
      await this.call('/launch', JSON.stringify({ bundle: bundle }));
      return true;
    } catch (error) {
      return false;
    }
  }

  async key(name: string): Promise<boolean> {
    try {
      await this.call('/key', JSON.stringify({ name: name }));
      return true;
    } catch (error) {
      return false;
    }
  }

  async swipe(fromX: number, fromY: number, toX: number, toY: number): Promise<boolean> {
    try {
      await this.call('/swipe', JSON.stringify({
        from_x: fromX,
        from_y: fromY,
        to_x: toX,
        to_y: toY,
        velocity: 600
      }));
      return true;
    } catch (error) {
      return false;
    }
  }
}
