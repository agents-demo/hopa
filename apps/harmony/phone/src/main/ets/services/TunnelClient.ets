import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { webSocket, socket } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsStore, StoredSettings } from './SettingsStore';
import { BridgeSessionStore, BridgeSessionRecord } from './BridgeSessionStore';
import { AgentService } from './AgentService';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA';
const SESSION: string = 'default';
const DEVICE_PORT: number = 5555;

const OPEN: number = 1;
const DATA: number = 2;
const CLOSE: number = 3;
const STATUS: number = 4;

/** One hdc TCP connection, opened by an OPEN frame from the PC. */
class TunnelStream {
  id: number;
  tcp: socket.TCPSocket | undefined = undefined;
  connecting: boolean = false;
  closed: boolean = false;
  pending: ArrayBuffer[] = [];

  constructor(id: number) {
    this.id = id;
  }
}

/** What Settings and the Permissions card show. */
export class TunnelSnapshot {
  enabled: boolean = false;
  relay: string = 'off';
  device: string = 'not connected';
  ready: boolean = false;
  error: string = '';
}

/**
 * The phone half of the hdc-over-relay tunnel.
 *
 * The phone dials *out* to the relay, so it works on mobile data and behind
 * NAT. The relay pairs this side with `pc-agent hdc-tunnel`; each OPEN frame
 * becomes a TCP connection to the local hdcd on 127.0.0.1:5555.
 *
 * This class never touches the bridge HTTP path. If it fails, chat and the
 * conversation store keep working.
 */
export class TunnelClient {
  private static instance: TunnelClient | undefined = undefined;

  private context: common.UIAbilityContext | undefined = undefined;
  private ws: webSocket.WebSocket | undefined = undefined;
  private enabled: boolean = false;
  private connecting: boolean = false;
  private ready: boolean = false;
  private relay: string = 'off';
  private device: string = 'not connected';
  private lastError: string = '';
  private streams: Map<number, TunnelStream> = new Map();
  private url: string = '';
  private token: string = '';
  private retry: number = 0;
  private retryTimer: number = -1;
  private keepAlive: boolean = false;

  static get(): TunnelClient {
    if (TunnelClient.instance === undefined) {
      TunnelClient.instance = new TunnelClient();
    }
    return TunnelClient.instance;
  }

  isEnabled(): boolean {
    return this.enabled;
  }

  snapshot(): TunnelSnapshot {
    const body = new TunnelSnapshot();
    body.enabled = this.enabled;
    body.relay = this.relay;
    body.device = this.device;
    body.ready = this.ready;
    body.error = this.lastError;
    return body;
  }

  /** A launch or a Settings change can supply the pair without a disk read. */
  configure(url: string, token: string): void {
    this.url = TunnelClient.websocketUrl(url);
    this.token = token.trim();
  }

  /** Turn the tunnel on or off. The caller persists the preference. */
  async setEnabled(context: common.UIAbilityContext, on: boolean): Promise<void> {
    this.context = context;
    this.enabled = on;
    this.retry = 0;
    this.publish();
    if (!on) {
      this.stop();
      return;
    }
    await this.start();
  }

  /** Start from saved settings; called at boot and when Settings opens. */
  async startIfWanted(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    let stored: StoredSettings = new StoredSettings();
    try {
      stored = await SettingsStore.load(context);
    } catch (error) {
      return;
    }
    if (!stored.tunnel) {
      return;
    }
    let token: string = this.token.length > 0 ? this.token : stored.bridgeToken;
    try {
      const session: BridgeSessionRecord = await BridgeSessionStore.load();
      if (session.token.length > 0) {
        token = session.token;
      }
    } catch (error) {
      // Keep the stored fallback.
    }
    this.configure(stored.bridgeUrl, token);
    this.enabled = true;
    this.publish();
    await this.start();
  }

  async start(): Promise<void> {
    if (this.ws !== undefined || this.connecting) {
      return;
    }
    if (this.url.length === 0 || this.token.length === 0) {
      this.relay = 'not configured';
      this.device = 'no bridge token';
      this.publish();
      return;
    }
    await this.keepAwake();
    this.connect();
  }

  /**
   * A background WebSocket is suspended when HarmonyOS freezes the app. The
   * existing continuous task is ref-counted, so a run and the tunnel can share
   * it without one ending the other.
   */
  private async keepAwake(): Promise<void> {
    if (this.keepAlive || this.context === undefined) {
      return;
    }
    this.keepAlive = true;
    const service = AgentService.get();
    service.background.setContext(this.context);
    await service.background.begin();
  }

  private releaseAwake(): void {
    if (!this.keepAlive) {
      return;
    }
    this.keepAlive = false;
    AgentService.get().background.end().catch((error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, `tunnel: background stop failed ${error.message}`);
    });
  }

  stop(): void {
    this.enabled = false;
    this.releaseAwake();
    this.retry = 0;
    if (this.retryTimer >= 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
    const ws: webSocket.WebSocket | undefined = this.ws;
    this.ws = undefined;
    if (ws !== undefined) {
      ws.close().catch((error: BusinessError) => {
        hilog.warn(DOMAIN, TAG, `tunnel: close failed ${error.message}`);
      });
    }
    this.closeAllStreams();
    this.connecting = false;
    this.ready = false;
    this.relay = 'off';
    this.device = 'not connected';
    this.publish();
  }

  /** Returning to the foreground is a good time to repair a dropped socket. */
  wake(): void {
    if (this.enabled && this.ws === undefined && !this.connecting) {
      this.retry = 0;
      this.connect();
    }
  }

  // -- WebSocket ----------------------------------------------------------

  private static websocketUrl(bridgeUrl: string): string {
    let base: string = bridgeUrl.trim();
    if (base.length === 0) {
      return '';
    }
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = `http://${base}`;
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.startsWith('https://')) {
      base = `wss://${base.substring('https://'.length)}`;
    } else if (base.startsWith('http://')) {
      base = `ws://${base.substring('http://'.length)}`;
    }
    return `${base}/tunnel?role=phone&session=${SESSION}`;
  }

  private connect(): void {
    if (!this.enabled || this.connecting || this.url.length === 0) {
      return;
    }
    this.connecting = true;
    this.relay = 'connecting';
    this.device = 'waiting for PC';
    this.ready = false;
    this.publish();

    const ws: webSocket.WebSocket = webSocket.createWebSocket();
    this.ws = ws;
    ws.on('open', (err: BusinessError, value: Object) => {
      if (err) {
        this.fail(`open: ${err.message}`);
        return;
      }
      this.connecting = false;
      this.relay = 'connected';
      this.retry = 0;
      this.publish();
    });
    ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        this.fail(`message: ${err.message}`);
        return;
      }
      if (typeof value === 'string') {
        return;
      }
      this.onFrame(value as ArrayBuffer);
    });
    ws.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      this.disconnected(err ? `closed: ${err.message}` : 'closed');
    });
    ws.on('error', (err: BusinessError) => {
      this.fail(err.message.length > 0 ? err.message : 'websocket error');
    });
    ws.connect(this.url, {
      header: { 'Authorization': `Bearer ${this.token}` }
    }).then((ok: boolean) => {
      if (!ok) {
        this.fail('websocket refused');
      }
    }).catch((err: BusinessError) => {
      this.fail(err.message.length > 0 ? err.message : 'websocket connect failed');
    });
  }

  private fail(message: string): void {
    this.lastError = message;
    hilog.warn(DOMAIN, TAG, `tunnel: ${message}`);
    const ws: webSocket.WebSocket | undefined = this.ws;
    this.ws = undefined;
    if (ws !== undefined) {
      ws.close().catch(() => {
        // The socket that failed is already gone.
      });
    }
    this.disconnected(message);
  }

  private disconnected(reason: string): void {
    if (reason.length > 0) {
      this.lastError = reason;
    }
    this.connecting = false;
    this.ws = undefined;
    this.ready = false;
    this.closeAllStreams();
    this.device = 'not connected';
    this.relay = this.enabled ? 'reconnecting' : 'off';
    this.publish();
    if (this.enabled) {
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect(): void {
    if (this.retryTimer >= 0) {
      return;
    }
    const wait: number = Math.min(30000, 2000 * Math.pow(2, this.retry));
    this.retry = Math.min(this.retry + 1, 4);
    this.retryTimer = setTimeout(() => {
      this.retryTimer = -1;
      if (this.enabled) {
        this.connect();
      }
    }, wait);
  }

  // -- frames -------------------------------------------------------------

  private onFrame(buffer: ArrayBuffer): void {
    const bytes = new Uint8Array(buffer);
    if (bytes.length < 1) {
      return;
    }
    const kind: number = bytes[0];
    if (kind === STATUS) {
      let text: string = '';
      for (let index = 1; index < bytes.length; index++) {
        text += String.fromCharCode(bytes[index]);
      }
      if (text === 'ready') {
        this.ready = true;
        this.device = 'tunnel ready';
      } else {
        this.ready = false;
        this.device = 'waiting for PC';
      }
      this.publish();
      return;
    }
    if (bytes.length < 5) {
      return;
    }
    const stream: number = new DataView(buffer).getUint32(1);
    if (kind === OPEN) {
      this.openStream(stream);
    } else if (kind === DATA) {
      this.writeStream(stream, buffer.slice(5));
    } else if (kind === CLOSE) {
      this.closeStream(stream, true);
    }
  }

  private sendFrame(kind: number, stream: number, payload?: ArrayBuffer): void {
    const ws: webSocket.WebSocket | undefined = this.ws;
    if (ws === undefined) {
      return;
    }
    const body: Uint8Array = payload === undefined ? new Uint8Array(0) : new Uint8Array(payload);
    const frame = new Uint8Array(5 + body.length);
    frame[0] = kind;
    new DataView(frame.buffer).setUint32(1, stream);
    frame.set(body, 5);
    ws.send(frame.buffer).catch((error: BusinessError) => {
      this.fail(`send: ${error.message}`);
    });
  }

  // -- hdc TCP streams ----------------------------------------------------

  private openStream(id: number): void {
    if (this.streams.has(id)) {
      return;
    }
    const stream = new TunnelStream(id);
    this.streams.set(id, stream);
    const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
    stream.tcp = tcp;
    stream.connecting = true;

    tcp.on('message', (info: socket.SocketMessageInfo) => {
      if (!stream.closed) {
        this.sendFrame(DATA, id, info.message);
      }
    });
    tcp.on('close', () => {
      this.closeStream(id, true);
    });
    tcp.on('error', (error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, `tunnel: tcp ${id} ${error.message}`);
      this.device = 'device unreachable';
      this.publish();
      this.closeStream(id, true);
    });
    tcp.connect({
      address: { address: '127.0.0.1', port: DEVICE_PORT, family: 1 },
      timeout: 5000
    }).then(() => {
      stream.connecting = false;
      if (stream.closed) {
        return;
      }
      this.device = 'device connected';
      this.publish();
      const pending: ArrayBuffer[] = stream.pending;
      stream.pending = [];
      for (const chunk of pending) {
        this.writeStream(id, chunk);
      }
    }).catch((error: BusinessError) => {
      stream.connecting = false;
      if (stream.closed) {
        return;
      }
      this.lastError = `tcp: ${error.message}`;
      this.device = 'device unreachable';
      this.publish();
      this.closeStream(id, true);
    });
  }

  private writeStream(id: number, payload: ArrayBuffer): void {
    const stream: TunnelStream | undefined = this.streams.get(id);
    if (stream === undefined || stream.closed) {
      return;
    }
    if (stream.connecting || stream.tcp === undefined) {
      stream.pending.push(payload);
      return;
    }
    stream.tcp.send({ data: payload }).catch((error: BusinessError) => {
      hilog.warn(DOMAIN, TAG, `tunnel: send ${id} ${error.message}`);
      this.closeStream(id, true);
    });
  }

  private closeStream(id: number, notifyPc: boolean): void {
    const stream: TunnelStream | undefined = this.streams.get(id);
    if (stream === undefined) {
      return;
    }
    stream.closed = true;
    this.streams.delete(id);
    if (stream.tcp !== undefined) {
      stream.tcp.close().catch(() => {
        // Closing an already-broken socket is fine.
      });
    }
    if (notifyPc) {
      this.sendFrame(CLOSE, id);
    }
  }

  private closeAllStreams(): void {
    const ids: number[] = [];
    this.streams.forEach((stream: TunnelStream, id: number) => {
      ids.push(id);
    });
    for (const id of ids) {
      const stream: TunnelStream | undefined = this.streams.get(id);
      if (stream !== undefined) {
        stream.closed = true;
        if (stream.tcp !== undefined) {
          stream.tcp.close().catch(() => {
            // Best effort.
          });
        }
      }
    }
    this.streams.clear();
  }

  private publish(): void {
    AppStorage.setOrCreate<boolean>('hopa.tunnel', this.enabled);
    AppStorage.setOrCreate<string>('hopa.tunnelRelay', this.relay);
    AppStorage.setOrCreate<string>('hopa.tunnelDevice', this.device);
    AppStorage.setOrCreate<boolean>('hopa.tunnelReady', this.ready);
  }
}
