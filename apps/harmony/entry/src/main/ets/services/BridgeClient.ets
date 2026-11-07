import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';

export class BridgeNode {
  ref: string = '';
  text: string = '';
  description: string = '';
  type: string = '';
  bounds: number[] = [];
  clickable: boolean = false;
}

class BridgeObservationBody {
  text: string = '';
  nodes: BridgeNode[] = [];
  width: number = 0;
  height: number = 0;
}

class BridgeOkBody {
  ok: boolean = false;
}

class BridgeLaunchBody {
  ok: boolean = false;
  foreground: string = '';
}

class ScreenshotBody {
  image: string = '';
  mime: string = 'image/jpeg';
  bytes: number = 0;
}

/**
 * Client for `pc-agent bridge`.
 *
 * The phone asks the PC for the current layout and sends taps/types/launches
 * back. The token stays in memory only.
 */
export class BridgeClient {
  private baseUrl: string = '';
  private token: string = '';
  private lastText: string = '';
  private lastNodes: BridgeNode[] = [];
  private width: number = 0;
  private height: number = 0;
  private lastError: string = '';
  private foreground: string = '';

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
        const body: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
        throw new Error(`bridge HTTP ${response.responseCode}: ${body}`);
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
        const body: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
        throw new Error(`bridge HTTP ${response.responseCode}: ${body}`);
      }
      return buffer.from(response.result as ArrayBuffer).toString('utf8');
    } finally {
      client.destroy();
    }
  }

  async health(): Promise<boolean> {
    try {
      const raw: string = await this.get('/health');
      const parsed = JSON.parse(raw) as BridgeOkBody;
      this.lastError = parsed.ok ? '' : 'bridge said not ok';
      return parsed.ok;
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return false;
    }
  }

  async observe(): Promise<boolean> {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw: string = await this.call('/observe', '{}');
        const parsed = JSON.parse(raw) as BridgeObservationBody;
        this.lastText = parsed.text;
        this.lastNodes = parsed.nodes;
        this.width = parsed.width;
        this.height = parsed.height;
        this.lastError = '';
        return true;
      } catch (error) {
        this.lastError = `${(error as Error).message}`;
      }
    }
    return false;
  }

  boundsFor(ref: string): number[] {
    for (const node of this.lastNodes) {
      if (node.ref === ref) {
        return node.bounds;
      }
    }
    return [];
  }

  nodes(): BridgeNode[] {
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
      const raw: string = await this.call('/launch', JSON.stringify({ bundle: bundle }));
      const parsed = JSON.parse(raw) as BridgeLaunchBody;
      this.foreground = parsed.foreground;
      this.lastError = parsed.ok ? '' : 'bridge launch was not ok';
      return parsed.ok;
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return false;
    }
  }

  /** The bundle the bridge confirmed in front after the last launch, or ''. */
  lastForeground(): string {
    return this.foreground;
  }

  async key(name: string): Promise<boolean> {
    try {
      await this.call('/key', JSON.stringify({ name: name }));
      return true;
    } catch (error) {
      return false;
    }
  }

  /** A JPEG of the device screen as a data URI, or '' when unavailable. */
  async screenshot(): Promise<string> {
    try {
      const raw: string = await this.call('/screenshot', '{}');
      const parsed = JSON.parse(raw) as ScreenshotBody;
      this.lastError = '';
      return parsed.image.length > 0 ? `data:${parsed.mime};base64,${parsed.image}` : '';
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return '';
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
