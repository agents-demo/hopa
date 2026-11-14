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

class BridgeTunnelBody {
  ready: boolean = false;
  host: boolean = false;
  phone: boolean = false;
}

class BridgeOkBody {
  ok: boolean = false;
  linked: boolean = false;
  tunnel: BridgeTunnelBody | null = null;
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
  refresh: string = '';
  expires_in: number = 0;
}

class BridgeErrorBody {
  error: string = '';
}

class HttpAnswer {
  status: number = 0;
  body: string = '';
}

/** The pairing result the wizard hands to the store. */
export class BridgeSession {
  token: string = '';
  refresh: string = '';
}

/** Lets the client persist a rotated token without importing storage. */
export interface BridgeSessionSink {
  save(token: string, refresh: string): Promise<void>;
}

class VoicesBody {
  voices: string[] = [];
}

/**
 * Client for `hopa-bridge bridge`.
 *
 * The phone asks the PC for the current layout and sends taps/types/launches
 * back. The token stays in memory only.
 */
export class BridgeClient {
  private baseUrl: string = '';
  private token: string = '';
  private refresh: string = '';
  private renewing: boolean = false;
  private sessionSink: BridgeSessionSink | null = null;
  private lastText: string = '';
  private lastNodes: BridgeNode[] = [];
  private width: number = 0;
  private height: number = 0;
  private lastError: string = '';
  private foreground: string = '';
  private tunnelReady: boolean = false;
  private tunnelReported: boolean = false;
  private relayLinked: boolean = false;
  /** 'phone' or '2in1': which device this client wants when one port serves both. */
  private role: string = '';
  /** '' means "the machine that asked"; otherwise the device to act on. */
  private target: string = '';

  /**
   * Text a person typed, made safe for `http.request` and for a header.
   *
   * An IME or a paste can leave zero-width marks, a non-breaking space or
   * full-width punctuation in a field. The http client then rejects the whole
   * URL with "Invalid URL format or missing URL", which reads exactly like an
   * unreachable bridge and sends everyone hunting the tunnel. Only printable
   * ASCII belongs in a URL or a token, so strip everything else here.
   */
  private static cleanText(value: string): string {
    return value
      .replace(new RegExp('[\\u200B-\\u200D\\uFEFF\\u00A0\\u3000]', 'g'), '')
      .replace(new RegExp('[^\\x21-\\x7E]', 'g'), '')
      .trim();
  }

  /**
   * A bare host and `localhost` are normalised too: a reverse port listens on
   * 127.0.0.1, while `localhost` can resolve to ::1 and be refused.
   */
  private static normalize(url: string): string {
    const ascii: string = url
      .replace(/[\uFF1A]/g, ':')
      .replace(/[\uFF0F]/g, '/')
      .replace(/[\uFF0E]/g, '.')
      .replace(/\s+/g, '');
    let clean: string = BridgeClient.cleanText(ascii);
    // "Http ://host" is what an auto-capitalising IME makes of "http://host";
    // the space is gone by now, so a lower-cased scheme is the whole repair.
    const scheme: number = clean.indexOf('://');
    if (scheme > 0) {
      clean = clean.substring(0, scheme).toLowerCase() + clean.substring(scheme);
    }
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
    this.token = BridgeClient.cleanText(token).replace(/^Bearer\s+/i, '');
    this.refresh = '';
  }

  /** A paired session: the access token plus the token that renews it. */
  configureSession(url: string, token: string, refresh: string): void {
    this.baseUrl = BridgeClient.normalize(url);
    this.token = BridgeClient.cleanText(token).replace(/^Bearer\s+/i, '');
    this.refresh = refresh.trim();
  }

  /** Tells a pooled bridge which device this app is. */
  setRole(role: string): void {
    this.role = role.trim();
  }

  /** Ask the pool to act on another device; '' means this one. */
  setTarget(role: string): void {
    this.target = role.trim();
  }

  /** The device this run acts on; '' means the one that asked. */
  targetRole(): string {
    return this.target;
  }

  setSessionSink(sink: BridgeSessionSink): void {
    this.sessionSink = sink;
  }

  isConfigured(): boolean {
    return this.baseUrl.length > 0 && this.token.length > 0;
  }

  /** Where this client points, and the token it is currently using. */
  endpoint(): string {
    return this.baseUrl;
  }

  authToken(): string {
    return this.token;
  }

  lastPageText(): string {
    return this.lastText;
  }

  lastFailure(): string {
    return this.lastError;
  }

  /** True only when the relay says a phone tunnel is paired, not merely up. */
  tunnelIsReady(): boolean {
    return this.tunnelReady;
  }

  /** False for a local bridge or an older relay that has no tunnel block. */
  tunnelIsReported(): boolean {
    return this.tunnelReported;
  }

  relayIsLinked(): boolean {
    return this.relayLinked;
  }

  private async request(path: string, payload: string, method: http.RequestMethod): Promise<HttpAnswer> {
    const client = http.createHttp();
    try {
      let options: http.HttpRequestOptions;
      const authHeader: Record<string, string> = {
        'Authorization': `Bearer ${this.token}`
      };
      if (this.role.length > 0) {
        authHeader['X-Hopa-Role'] = this.target.length > 0 ? this.target : this.role;
      }
      if (method === http.RequestMethod.POST) {
        authHeader['Content-Type'] = 'application/json';
        options = {
          method: method,
          header: authHeader,
          extraData: payload,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 8000,
          readTimeout: 45000
        };
      } else {
        options = {
          method: method,
          header: authHeader,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          connectTimeout: 8000,
          readTimeout: 20000
        };
      }
      const response = await client.request(`${this.baseUrl}${path}`, options);
      const answer = new HttpAnswer();
      answer.status = response.responseCode;
      answer.body = buffer.from(response.result as ArrayBuffer).toString('utf8');
      return answer;
    } finally {
      client.destroy();
    }
  }

  /** Trade the refresh token for a fresh pair; the old pair dies on the PC. */
  private async renew(): Promise<boolean> {
    if (this.refresh.length === 0 || this.renewing) {
      return false;
    }
    this.renewing = true;
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'X-Hopa-Role': this.role
        },
        extraData: JSON.stringify({ refresh: this.refresh }),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 15000
      };
      const response = await client.request(`${this.baseUrl}/refresh`, options);
      if (response.responseCode !== 200) {
        return false;
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as PairBody;
      if (parsed.token.length === 0 || parsed.refresh.length === 0) {
        return false;
      }
      this.token = parsed.token;
      this.refresh = parsed.refresh;
      if (this.sessionSink !== null) {
        await this.sessionSink.save(this.token, this.refresh);
      }
      return true;
    } catch (error) {
      return false;
    } finally {
      this.renewing = false;
      client.destroy();
    }
  }

  /** One retry after a refresh: an expired token is an expected state. */
  private async send(path: string, payload: string, method: http.RequestMethod): Promise<string> {
    if (!this.isConfigured()) {
      throw new Error('bridge is not configured');
    }
    let answer: HttpAnswer = await this.request(path, payload, method);
    if (answer.status === 401) {
      const renewed: boolean = await this.renew();
      if (renewed) {
        answer = await this.request(path, payload, method);
      }
    }
    if (answer.status !== 200) {
      // A device error is a wall of JSON from `aa start`; the chat should not
      // receive it verbatim.
      let detail: string = answer.body;
      try {
        const parsed = JSON.parse(answer.body) as BridgeErrorBody;
        const message: string = `${parsed.error ?? ''}`;
        if (message.length > 0) {
          detail = message;
        }
      } catch (error) {
        // Not JSON: keep the text.
      }
      if (detail.length > 180) {
        detail = `${detail.substring(0, 180)}\u2026`;
      }
      throw new Error(`bridge HTTP ${answer.status}: ${detail}`);
    }
    return answer.body;
  }

  private async call(path: string, payload: string): Promise<string> {
    return this.send(path, payload, http.RequestMethod.POST);
  }

  private async get(path: string): Promise<string> {
    return this.send(path, '', http.RequestMethod.GET);
  }

  /** Authenticated: proves the token works, not just that a port is open. */
  async whoami(): Promise<boolean> {
    try {
      const raw: string = await this.get('/whoami');
      const parsed = JSON.parse(raw) as BridgeOkBody;
      this.lastError = parsed.ok ? '' : 'bridge rejected the key';
      return parsed.ok;
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return false;
    }
  }

  async health(): Promise<boolean> {
    // One retry: a socket can be refused while the reverse port reconnects.
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw: string = await this.get('/health');
        const parsed = JSON.parse(raw) as BridgeOkBody;
        this.lastError = parsed.ok ? '' : 'bridge said not ok';
        this.relayLinked = parsed.linked === true;
        this.tunnelReported = parsed.tunnel !== null && parsed.tunnel !== undefined;
        this.tunnelReady = this.tunnelReported && parsed.tunnel !== null && parsed.tunnel.ready === true;
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

  /** Close an app the agent opened; the inverse of a launch. */
  async stopApp(bundle: string): Promise<boolean> {
    try {
      await this.call('/stop', JSON.stringify({ bundle: bundle }));
      return true;
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return false;
    }
  }

  /**
   * Bring an app back to the front. Unlike `launch`, this is allowed to
   * restart it: a singleton ability can take the intent without raising its
   * window, and the user should not be stranded in whatever HOPA opened.
   */
  async focus(bundle: string, ability: string = ''): Promise<boolean> {
    try {
      const raw: string = await this.call('/focus', JSON.stringify({ bundle: bundle, ability: ability }));
      const parsed = JSON.parse(raw) as BridgeLaunchBody;
      this.foreground = parsed.foreground;
      this.lastError = parsed.ok ? '' : 'bridge could not raise the app';
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
  async screenshot(width: number = 0): Promise<string> {
    try {
      const body: string = `{"width":${width}}`;
      const raw: string = await this.call('/screenshot', body);
      const parsed = JSON.parse(raw) as ScreenshotBody;
      this.lastError = '';
      return parsed.image.length > 0 ? `data:${parsed.mime};base64,${parsed.image}` : '';
    } catch (error) {
      this.lastError = `${(error as Error).message}`;
      return '';
    }
  }

  /**
   * Trade the short pairing code shown by the PC for a token pair.
   *
   * The bridge is a pool, and an unauthenticated pair is routed by role. Without
   * the role a laptop pair lands on the phone's device entry: the code is
   * rejected, or a phone token is handed back to a 2-in-1.
   */
  static async pair(url: string, code: string, role: string = ''): Promise<BridgeSession> {
    const session = new BridgeSession();
    let base: string = url.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.length === 0 || code.trim().length === 0) {
      return session;
    }
    const client = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      if (role.length > 0) {
        header['X-Hopa-Role'] = role;
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify({ code: code.trim() }),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 15000
      };
      const response = await client.request(`${base}/pair`, options);
      if (response.responseCode !== 200) {
        return session;
      }
      const raw: string = buffer.from(response.result as ArrayBuffer).toString('utf8');
      const parsed = JSON.parse(raw) as PairBody;
      session.token = parsed.token;
      session.refresh = parsed.refresh;
      return session;
    } catch (error) {
      return session;
    } finally {
      client.destroy();
    }
  }

  /** Hand a snapshot of the conversations to the bridge (H3 relay). */
  async pushSessions(payload: string): Promise<boolean> {
    try {
      await this.call('/sessions', payload);
      return true;
    } catch (error) {
      return false;
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
