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

class BridgeForegroundBody {
  bundle: string = '';
}

class ScreenshotBody {
  image: string = '';
  mime: string = 'image/jpeg';
  bytes: number = 0;
}

class TranscribeBody {
  text: string = '';
}

class SpeakBody {
  mime: string = 'audio/wav';
  audio: string = '';
}

class PairBody {
  token: string = '';
}

class VoicesBody {
  voices: string[] = [];
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

  /**
   * A bare host and `localhost` are normalised here: a reverse port listens on
   * 127.0.0.1, while `localhost` can resolve to ::1 and be refused.
   */
  private static normalize(url: string): string {
    let clean: string = url.trim();
    if (clean.length > 0 && !clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = `http://${clean}`;
    }
    clean = clean.replace('://localhost', '://127.0.0.1');
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  configure(url: string, token: string): void {
    this.baseUrl = BridgeClient.normalize(url);
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
    // One retry: a socket can be refused while the reverse port reconnects.
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw: string = await this.get('/health');
        const parsed = JSON.parse(raw) as BridgeOkBody;
        this.lastError = parsed.ok ? '' : 'bridge said not ok';
        return parsed.ok;
      } catch (error) {
        this.lastError = `${(error as Error).message}`;
        if (attempt === 0) {
          await new Promise<void>((resolve: () => void) => {
            setTimeout(resolve, 400);
          });
        }
      }
    }
    return false;
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

  /** Ask the phone which app is in front right now; '' when unreachable. */
  async foregroundBundle(): Promise<string> {
    try {
      const raw: string = await this.call('/foreground', '{}');
      const parsed = JSON.parse(raw) as BridgeForegroundBody;
      return parsed.bundle;
    } catch (error) {
      return '';
    }
  }

  async key(name: string, count: number = 1): Promise<boolean> {
    try {
      await this.call('/key', JSON.stringify({ name: name, count: count }));
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

  /** Trade the short pairing code shown by the PC for the full token. */
  static async pair(url: string, code: string): Promise<string> {
    let base: string = url.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.length === 0 || code.trim().length === 0) {
      return '';
    }
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ code: code.trim() }),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 15000
      };
      const response = await client.request(`${base}/pair`, options);
      if (response.responseCode !== 200) {
        return '';
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      return (JSON.parse(raw) as PairBody).token;
    } catch (error) {
      return '';
    } finally {
      client.destroy();
    }
  }

  /** Speech-to-text on the PC; '' when it did not catch anything. */
  async transcribe(wavBase64: string): Promise<string> {
    const raw: string = await this.call('/transcribe', JSON.stringify({ audio: wavBase64 }));
    const parsed = JSON.parse(raw) as TranscribeBody;
    return parsed.text;
  }

  /** A spoken WAV reply from the PC, base64 encoded. */
  async speak(text: string, voice: string = ''): Promise<string> {
    const raw: string = await this.call('/speak', JSON.stringify({
      text: text,
      voice: voice
    }));
    const parsed = JSON.parse(raw) as SpeakBody;
    return parsed.audio;
  }

  /** Installed voices on the PC; empty when the bridge is unavailable. */
  async voices(): Promise<string[]> {
    try {
      const raw: string = await this.call('/voices', '{}');
      const parsed = JSON.parse(raw) as VoicesBody;
      return parsed.voices;
    } catch (error) {
      return [];
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
