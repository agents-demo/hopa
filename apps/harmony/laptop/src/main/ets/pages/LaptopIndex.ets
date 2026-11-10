import { common } from '@kit.AbilityKit';
import { RunRecord, RunStatus } from '@hopa/core';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { HopaMark, EmptyHero, ResultActions, StepChips, ChatFormat, Character, KeyStore, SettingsStore, StoredSettings } from '@hopa/app';
import { LaptopChat, LaptopTurn } from '../services/LaptopChat';
import { LaptopAgent, demoApproval } from '../services/LaptopAgent';

import { LaptopSessions, LaptopSession } from '../services/LaptopSessions';
import { LaptopVoice } from '../services/LaptopVoice';
import { ChatRail } from '../components/ChatRail';
import { CommandPalette } from '../components/CommandPalette';
import { LaptopFirstRun } from '../services/LaptopFirstRun';

const LAPTOP_KEY_ALIAS: string = 'hopa_laptop_key';

/**
 * The HOPA workbench: one conversation, one input, everything else quiet.
 *
 * This shell runs the agent on the laptop itself. It never drives the phone,
 * and it never borrows the phone's key.
 */
@Entry
@Component
struct LaptopIndex {
  @State turns: LaptopTurn[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State keyPresent: boolean = false;
  @State modelName: string = 'deepseek-v4-flash';
  @State provider: string = 'deepseek';
  @State endpoint: string = 'https://api.deepseek.com/v1';
  @State settingsOpen: boolean = false;
  @State keyDraft: string = '';
  @State saved: string = '';
  @State paletteOpen: boolean = false;
  @State lastQuestion: string = '';
  @State sessions: LaptopSession[] = [];
  @State bridgeUrl: string = '';
  @State bridgeToken: string = '';
  @State bridgeStatus: string = '';
  @State bridgeLive: boolean = false;
  @State approvalOpen: boolean = false;
  @State approvalDetail: string = '';
  @State approvalKind: string = '';
  @State approvalFrame: string = '';
  @State listening: boolean = false;
  @State query: string = '';
  @State view: string = 'chat';
  @State runs: RunRecord[] = [];
  @State openRunId: string = '';
  @State speakReplies: boolean = false;
  @State profileName: string = 'everyday';
  @State kidPin: string = '';
  @State pinPrompt: boolean = false;
  @State pinSetMode: boolean = false;
  @State pinDraft: string = '';
  @State pinError: string = '';
  @State pinIntent: string = '';
  private voice: LaptopVoice = new LaptopVoice();
  @State currentId: string = '';
  private store: LaptopSessions = new LaptopSessions();
  private win: window.Window | undefined = undefined;
  @State maximized: boolean = false;
  @StorageProp('hopa.decorHidden') decorHidden: boolean = false;
  @StorageProp('hopa.laptop.focused') focused: boolean = true;
  @State currentTitle: string = 'HOPA';
  @State lastLatency: number = 0;
  @State lastTokens: number = 0;
  @State winWidth: number = 1280;
  @StorageLink('hopa.laptop.pending') @Watch('onPending') pending: string = '';
  private deferredAsk: string = '';
  private chat: LaptopChat = new LaptopChat();
  private agent: LaptopAgent = new LaptopAgent();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.chat.useRuntime(this.agent.runtime);
    this.store.attachSync(this.agent.chatSync);
    this.agent.approvals.onAsk = (kind: string, detail: string) => {
      this.approvalKind = kind;
      this.approvalDetail = detail;
      // A frame the run already captured: proof of what the step was about.
      const shots: string[] = this.agent.runtime.stepShots();
      this.approvalFrame = shots.length > 0 ? shots[shots.length - 1] : '';
      this.approvalOpen = true;
    };
    window.getLastWindow(context).then((win: window.Window) => {
      this.win = win;
    }).catch(() => {
      // The system bar remains if the window cannot be reached.
    });
    LaptopSessions.load(context).then((store: LaptopSessions) => {
      this.store = store;
      // The loaded instance replaces the placeholder, so attach again.
      this.store.attachSync(this.agent.chatSync);
      this.store.prune();
      this.store.save(context);
      const session: LaptopSession = store.current();
      this.chat.turns = session.turns.slice();
      this.turns = session.turns.slice();
      this.lastLatency = session.lastLatency;
      this.lastTokens = session.lastTokens;
      this.refreshSessions();
      this.syncChats();
      this.agent.archive.load(context).then(() => {
        this.runs = this.agent.runs.all().reverse();
      }).catch(() => {
        this.runs = [];
      });
      if ((AppStorage.get<string>('hopa.laptop.new') ?? '') === '1') {
        AppStorage.setOrCreate<string>('hopa.laptop.new', '');
        this.newChat();
      }
      for (let i = this.turns.length - 1; i >= 0; i--) {
        if (this.turns[i].role === 'user') {
          this.lastQuestion = this.turns[i].text;
          break;
        }
      }
    }).catch(() => {
      // An unreadable store is an empty one.
    });
    LaptopFirstRun.ensure(context).then((stored: StoredSettings) => {
      this.endpoint = stored.endpoint;
      this.modelName = stored.model;
      this.provider = stored.provider;
      this.speakReplies = stored.speakReplies;
      this.profileName = stored.profile;
      this.kidPin = stored.kidPin;
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        this.agent.configureBridge(stored.bridgeUrl, stored.bridgeToken);
        this.checkBridge();
      }
      KeyStore.load(LAPTOP_KEY_ALIAS).then((key: string) => {
        this.keyPresent = key.length > 0;
        this.chat.configure(this.provider, this.endpoint, this.modelName, key);
        this.applyInjected().then(() => {
          this.runDeferredAsk();
        });
      }).catch(() => {
        // No key yet: the Model panel asks for one.
        this.applyInjected().then(() => {
          this.runDeferredAsk();
        });
      });
    }).catch(() => {
      // Defaults are fine.
    });
    // A pending ask can already be set when the page is created; @Watch only
    // fires on later changes, so read it once here.
    if (this.pending.length > 0) {
      this.onPending();
    }
    if ((AppStorage.get<string>('hopa.laptop.demoApproval') ?? '') === '1') {
      AppStorage.setOrCreate<string>('hopa.laptop.demoApproval', '');
      demoApproval(this.agent);
    }
  }

  /** One button: tap to talk, tap again to send what was heard. */
  private async toggleMic(): Promise<void> {
    if (this.busy) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (this.listening) {
      this.listening = false;
      const heard: string = await this.voice.stop(this.agent);
      if (heard.length > 0) {
        this.draft = heard;
        await this.send();
      } else {
        this.error = this.agent.isBridgeConfigured()
          ? 'I did not catch that. Try again, a little closer.'
          : 'Voice needs the PC bridge: start it, then connect in Settings.';
      }
      return;
    }
    if (!this.agent.isBridgeConfigured()) {
      this.error = 'Voice needs the PC bridge: start it, then connect in Settings.';
      return;
    }
    const started: boolean = await this.voice.start(context);
    this.listening = started;
    if (!started) {
      this.error = 'The microphone is not available.';
    } else {
      this.error = '';
    }
  }

  private async retryRun(): Promise<void> {
    await this.chat.retry();
    this.turns = this.chat.turns.slice();
    this.lastQuestion = this.chat.lastQuestion;
    this.lastLatency = this.chat.lastLatencyMs;
    this.lastTokens = this.chat.lastTokens;
    this.busy = this.chat.busy;
  }

  private copyText(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).catch(() => {});
    } catch (error) {
      // Clipboard is best effort.
    }
  }

  private listedSessions(): LaptopSession[] {
    const needle: string = this.query.trim().toLowerCase();
    const shown: LaptopSession[] = [];
    for (const session of this.sessions) {
      if (session.turns.length === 0) {
        continue;
      }
      if (needle.length === 0) {
        shown.push(session);
        continue;
      }
      if (session.title.toLowerCase().includes(needle)) {
        shown.push(session);
        continue;
      }
      for (const turn of session.turns) {
        if (turn.text.toLowerCase().includes(needle)) {
          shown.push(session);
          break;
        }
      }
    }
    return shown;
  }

  /** Ask the bridge for the shared list; it is the store of record. */
  private async syncChats(): Promise<void> {
    await this.store.syncNow();
    const context = getContext(this) as common.UIAbilityContext;
    await this.store.save(context);
    this.refreshSessions();
    const session: LaptopSession = this.store.current();
    this.chat.turns = session.turns.slice();
    this.turns = session.turns.slice();
  }

  private refreshSessions(): void {
    this.sessions = this.store.list.slice();
    this.currentId = this.store.currentId;
    for (const session of this.sessions) {
      if (session.id === this.currentId) {
        this.currentTitle = session.turns.length > 0 ? session.title : 'HOPA';
        break;
      }
    }
  }

  private minimizeWindow(): void {
    if (this.win !== undefined) {
      this.win.minimize().catch(() => {});
    }
  }

  private toggleMaximize(): void {
    if (this.win === undefined) {
      return;
    }
    if (this.maximized) {
      this.win.recover().then(() => {
        this.maximized = false;
      }).catch(() => {});
    } else {
      this.win.maximize().then(() => {
        this.maximized = true;
      }).catch(() => {});
    }
  }

  private closeWindow(): void {
    if (this.win !== undefined) {
      this.win.destroyWindow().catch(() => {});
    }
  }

  /** Phone turns carry a [meta] line; the laptop shows the words only. */
  private cleanRemote(text: string): string {
    const lines: string[] = text.split('\n');
    const kept: string[] = [];
    for (const line of lines) {
      if (!line.startsWith('[meta]')) {
        kept.push(line);
      }
    }
    return kept.join('\n').trim();
  }

  private focusRoot(): void {
    try {
      focusControl.requestFocus('hopa-root');
    } catch (error) {
      // Focus control is best effort.
    }
  }

  private newChat(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.settingsOpen = false;
    const current: LaptopSession = this.store.current();
    if (current.turns.length === 0) {
      // Already a blank thread: put the caret where the user will type.
      this.chat.clear();
      this.turns = [];
      this.error = '';
      this.lastQuestion = '';
      this.lastLatency = 0;
      this.lastTokens = 0;
      this.refreshSessions();
      try {
        focusControl.requestFocus('hopa-composer');
      } catch (error) {
        // Focus is best effort.
      }
      return;
    }
    this.store.create();
    this.chat.clear();
    this.turns = [];
    this.error = '';
    this.lastQuestion = '';
    this.lastLatency = 0;
    this.lastTokens = 0;
    this.refreshSessions();
    this.store.save(context);
  }

  private openSession(id: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.settingsOpen = false;
    this.store.select(id);
    this.store.save(context);
    const session: LaptopSession = this.store.current();
    this.chat.turns = session.turns.slice();
    this.turns = session.turns.slice();
    this.lastLatency = session.lastLatency;
    this.lastTokens = session.lastTokens;
    this.error = '';
    this.lastQuestion = '';
    for (let i = this.turns.length - 1; i >= 0; i--) {
      if (this.turns[i].role === 'user') {
        this.lastQuestion = this.turns[i].text;
        break;
      }
    }
    this.refreshSessions();
  }

  private deleteSession(id: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.store.removeEverywhere(id);
    if (this.store.currentId.length === 0) {
      this.store.create();
    }
    this.store.save(context);
    this.openSession(this.store.currentId);
  }

  /** `aa start --ps hopa.ask`, or a hopa://ask link, asks without typing. */
  onPending(): void {
    const text: string = this.pending;
    if (text.length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>('hopa.laptop.pending', '');
    this.draft = text;
    if (this.chat.isReady()) {
      this.send();
    } else {
      this.deferredAsk = text;
    }
  }

  private runDeferredAsk(): void {
    if (this.deferredAsk.length === 0) {
      return;
    }
    this.draft = this.deferredAsk;
    this.deferredAsk = '';
    this.send();
  }

  /** A scripted first run can pass the key once; it lands in Asset Store and is forgotten. */
  private async applyInjected(): Promise<void> {
    const injectedKey: string = AppStorage.get<string>('hopa.laptop.key') ?? '';
    const injectedEndpoint: string = AppStorage.get<string>('hopa.laptop.endpoint') ?? '';
    const injectedModel: string = AppStorage.get<string>('hopa.laptop.model') ?? '';
    const injectedBridgeUrl: string = AppStorage.get<string>('hopa.laptop.bridgeUrl') ?? '';
    const injectedBridgeToken: string = AppStorage.get<string>('hopa.laptop.bridgeToken') ?? '';
    if (injectedEndpoint.length === 0 && injectedModel.length === 0 && injectedKey.length === 0 &&
      injectedBridgeUrl.length === 0 && injectedBridgeToken.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (injectedEndpoint.length > 0 || injectedModel.length > 0) {
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.endpoint = injectedEndpoint.length > 0 ? injectedEndpoint : stored.endpoint;
      stored.model = injectedModel.length > 0 ? injectedModel : stored.model;
      await SettingsStore.save(context, stored);
      this.endpoint = stored.endpoint;
      this.modelName = stored.model;
      AppStorage.setOrCreate<string>('hopa.laptop.endpoint', '');
      AppStorage.setOrCreate<string>('hopa.laptop.model', '');
    }
    if (injectedKey.length > 0) {
      const saved: boolean = await KeyStore.save(injectedKey, LAPTOP_KEY_ALIAS);
      AppStorage.setOrCreate<string>('hopa.laptop.key', '');
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.keyPresent = key.length > 0;
      this.saved = this.keyPresent ? 'Key saved.' : 'Key store unavailable.';
      this.chat.configure(this.provider, this.endpoint, this.modelName, key);
    }
    if (injectedBridgeUrl.length > 0 || injectedBridgeToken.length > 0) {
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.bridgeUrl = injectedBridgeUrl.length > 0 ? injectedBridgeUrl : stored.bridgeUrl;
      stored.bridgeToken = injectedBridgeToken.length > 0 ? injectedBridgeToken : stored.bridgeToken;
      await SettingsStore.save(context, stored);
      AppStorage.setOrCreate<string>('hopa.laptop.bridgeUrl', '');
      AppStorage.setOrCreate<string>('hopa.laptop.bridgeToken', '');
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        this.agent.configureBridge(stored.bridgeUrl, stored.bridgeToken);
        this.checkBridge();
      }
    }
  }

  private async send(): Promise<void> {
    if (this.draft.trim().length === 0 || this.busy) {
      return;
    }
    if (!this.chat.isReady()) {
      this.error = 'Add a model key to send. Settings is in the sidebar.';
      return;
    }
    const text: string = this.draft;
    this.draft = '';
    this.busy = true;
    await this.chat.send(text);
    this.turns = this.chat.turns.slice();
    this.error = this.chat.error;
    this.lastQuestion = this.chat.lastQuestion;
    this.lastLatency = this.chat.lastLatencyMs;
    this.lastTokens = this.chat.lastTokens;
    this.busy = false;
    this.scrollToEnd();
    const context = getContext(this) as common.UIAbilityContext;
    if (this.speakReplies && this.chat.turns.length > 0) {
      const last = this.chat.turns[this.chat.turns.length - 1];
      if (last.role === 'assistant') {
        this.voice.speak(this.agent, last.text, context);
      }
    }
    if (!this.focused) {
      this.notifyAnswer(text.length > 0 ? this.lastQuestion : 'HOPA');
    }
    this.store.commit(this.chat.turns, this.chat.lastLatencyMs, this.chat.lastTokens);
    await this.store.save(context);
    this.refreshSessions();
    this.syncChats();
    this.runs = this.agent.runs.all().reverse();
    this.agent.archive.save(context);
  }

  /** Ctrl+K opens the palette; Esc closes it. Phone shells never see these. */
  private handleShortcut(event: KeyEvent): boolean {
    if (event.type !== KeyType.Down) {
      return false;
    }
    if (event.keyCode === 2070) {
      if (this.paletteOpen) {
        this.paletteOpen = false;
        this.focusRoot();
        return true;
      }
      if (this.settingsOpen) {
        this.settingsOpen = false;
        return true;
      }
      if (this.busy) {
        this.chat.cancel();
        return true;
      }
      return false;
    }
    const key: string = event.keyText.toLowerCase();
    if (key === 'k') {
      const ctrl: boolean = event.getModifierKeyState
        ? event.getModifierKeyState(['ctrl'])
        : false;
      const meta: boolean = event.getModifierKeyState
        ? event.getModifierKeyState(['meta'])
        : false;
      if (ctrl || meta) {
        this.paletteOpen = !this.paletteOpen;
        return true;
      }
    }
    return false;
  }

  private scrollToEnd(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 220);
  }

  /** Save the bridge pair, then ask it a real question: are you there? */
  private async saveBridge(): Promise<void> {
    const url: string = this.bridgeUrl.trim();
    const token: string = this.bridgeToken.trim();
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.bridgeUrl = url;
    stored.bridgeToken = token;
    await SettingsStore.save(context, stored);
    if (url.length === 0 || token.length === 0) {
      this.bridgeLive = false;
      this.bridgeStatus = 'Not connected.';
      return;
    }
    this.agent.configureBridge(url, token);
    await this.checkBridge();
  }

  /** A real request, so the bridge line reports the truth rather than the config. */
  private async checkBridge(): Promise<void> {
    if (!this.agent.isBridgeConfigured()) {
      this.bridgeLive = false;
      this.bridgeStatus = '';
      return;
    }
    this.bridgeStatus = 'Checking\u2026';
    const ok: boolean = await this.agent.testBridge();
    this.bridgeLive = ok;
    this.bridgeStatus = ok ? 'Connected.' : `No answer from the bridge. ${this.agent.bridgeFailure()}`;
    if (ok) {
      this.syncChats();
    }
  }

  /** Speaking replies is a preference, not a model setting. */
  private async saveSpeak(value: boolean): Promise<void> {
    this.speakReplies = value;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.speakReplies = value;
    await SettingsStore.save(context, stored);
  }

  /** A system notification only when the window is not the one in front. */
  private notifyAnswer(question: string): void {
    try {
      const request: notificationManager.NotificationRequest = {
        id: 1,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'HOPA has an answer',
            text: question
          }
        }
      };
      notificationManager.publish(request).catch(() => {});
    } catch (error) {
      // Notifications are a courtesy, never a dependency.
    }
  }

  private async saveSettings(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.endpoint = this.endpoint.trim().length > 0 ? this.endpoint.trim() : stored.endpoint;
    stored.model = this.modelName.trim().length > 0 ? this.modelName.trim() : stored.model;
    await SettingsStore.save(context, stored);
    if (this.keyDraft.trim().length > 0) {
      const ok: boolean = await KeyStore.save(this.keyDraft, LAPTOP_KEY_ALIAS);
      this.saved = ok ? 'Saved.' : 'That key looks too short.';
      this.keyDraft = '';
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.keyPresent = key.length > 0;
      this.chat.configure(stored.provider, stored.endpoint, stored.model, key);
    } else {
      this.saved = 'Saved.';
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.chat.configure(stored.provider, stored.endpoint, stored.model, key);
    }
    this.modelName = stored.model;
    this.endpoint = stored.endpoint;
    this.provider = stored.provider;
  }

  @Builder
  ModeChip(mode: string) {
    Text(mode.charAt(0).toUpperCase() + mode.substring(1))
      .fontSize(11.5)
      .fontColor(this.profileName === mode
        ? $r('app.color.on_primary')
        : $r('app.color.text_secondary'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.profileName === mode
        ? $r('app.color.primary')
        : $r('app.color.surface'))
      .borderRadius(12)
      .onClick(() => {
        this.setProfile(mode);
      })
  }

  @Builder
  Header() {
    Row({ space: 12 }) {
      HopaMark({ state: 'idle', markSize: 26, interactive: false, body: 'laptop' })
      Column({ space: 1 }) {
        Text(this.currentTitle)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(-0.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 320 })
        Text('Running on this laptop')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .alignItems(HorizontalAlign.Start)
      Row()
        .layoutWeight(1)
        .height('100%')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down && this.win !== undefined) {
            this.win.startMoving().catch(() => {});
          }
        })
        .gesture(TapGesture({ count: 2 }).onAction(() => {
          this.toggleMaximize();
        }))
      if (!this.showSidebar()) {
        Text('New')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(16)
          .onClick(() => {
            this.newChat();
          })
      }
      if (this.decorHidden) {
        Row({ space: 2 }) {
          Text('\u2013')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.minimizeWindow();
            })
          Text(this.maximized ? '\u2750' : '\u25a1')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.toggleMaximize();
            })
          Text('\u00d7')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.closeWindow();
            })
        }
        .padding({ left: 4, right: 4 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 22, right: 22 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  FieldLabel(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  @Builder
  SettingsPanel() {
    Column({ space: 22 }) {
      Row() {
        Text('Settings')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('\u00d7')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .onClick(() => {
            this.settingsOpen = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Text('MODE')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')
        Row({ space: 6 }) {
          ForEach(['everyday', 'easy', 'power'], (mode: string) => {
            this.ModeChip(mode)
          }, (mode: string) => 'mode-a-' + mode + (this.profileName === mode))
        }
        .width('100%')
        Row({ space: 6 }) {
          ForEach(['social', 'kid'], (mode: string) => {
            this.ModeChip(mode)
          }, (mode: string) => 'mode-b-' + mode + (this.profileName === mode))
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Divider().color($r('app.color.divider'))

      Column({ space: 8 }) {
        Text('MODEL')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')

        this.FieldLabel('Endpoint')
        TextInput({ text: this.endpoint, placeholder: 'https://api.deepseek.com/v1' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.endpoint = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })
          .onBlur(() => {
            this.saveSettings();
          })

        this.FieldLabel('Model')
        TextInput({ text: this.modelName, placeholder: 'deepseek-v4-flash' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.modelName = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })
          .onBlur(() => {
            this.saveSettings();
          })

        this.FieldLabel(this.keyPresent ? 'API key (stored; leave blank to keep it)' : 'API key')
        TextInput({ text: this.keyDraft, placeholder: this.keyPresent ? 'stored in Asset Store' : 'paste your key' })
          .height(38)
          .fontSize(12.5)
          .type(InputType.Password)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.keyDraft = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })

        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('Speak replies')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
            Text('Uses the PC voice over the bridge.')
              .fontSize(10.5)
              .fontColor($r('app.color.text_hint'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.speakReplies })
            .selectedColor($r('app.color.primary'))
            .onChange((value: boolean) => {
              this.saveSpeak(value);
            })
        }
        .width('100%')
        .padding({ top: 6 })

        Text('Changes save when you leave a field. The key lives in Asset Store on this laptop, never in the app package.')
          .fontSize(10.5)
          .lineHeight(16)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
        if (this.saved.length > 0) {
          Text(this.saved)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Divider().color($r('app.color.divider'))

      Column({ space: 8 }) {
        Text('PC BRIDGE')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')

        Text('Gives HOPA eyes and hands on this laptop: it reads the screen and taps, types or opens apps through a bridge running on a PC connected by USB. Every action still asks you first, and nothing happens while the tunnel is down.')
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        this.FieldLabel('Bridge address')
        TextInput({ text: this.bridgeUrl, placeholder: 'http://127.0.0.1:8767' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.bridgeUrl = value;
          })
          .onSubmit(() => {
            this.saveBridge();
          })
          .onBlur(() => {
            this.saveBridge();
          })

        this.FieldLabel('Bridge key')
        TextInput({ text: this.bridgeToken, placeholder: 'from the bridge output' })
          .height(38)
          .fontSize(12.5)
          .type(InputType.Password)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.bridgeToken = value;
          })
          .onSubmit(() => {
            this.saveBridge();
          })

        Row({ space: 12 }) {
          Text('Connect')
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary_soft'))
            .borderRadius(14)
            .onClick(() => {
              this.saveBridge();
            })
          if (this.bridgeStatus.length > 0) {
            Text(this.bridgeStatus)
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text('HOPA runs here, on this laptop. Payments always ask first.')
        .fontSize(10.5)
        .fontColor($r('app.color.text_hint'))
        .width('100%')
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 28 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActivityPane() {
    Column({ space: 8 }) {
      Row() {
        Text('Activity')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('Steps this laptop actually took')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })

      if (this.runs.length === 0) {
        Text('Nothing yet. Every action HOPA takes lands here, with what happened.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
          .padding({ top: 8 })
      } else {
        List({ space: 6 }) {
          ForEach(this.runs.slice(0, 80), (run: RunRecord) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 8 }) {
                  Row()
                    .width(7)
                    .height(7)
                    .borderRadius(4)
                    .backgroundColor(run.status === RunStatus.Executed
                      ? $r('app.color.success')
                      : (run.status === RunStatus.Denied
                        ? $r('app.color.warning')
                        : $r('app.color.danger')))
                  Text(run.kind)
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                  Text(`${run.durationMs} ms`)
                    .fontSize(10.5)
                    .fontColor($r('app.color.text_hint'))
                }
                .width('100%')
                Text(run.detail.length > 0 ? run.detail : run.status)
                  .fontSize(11.5)
                  .lineHeight(16)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(this.openRunId === run.id ? 8 : 2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                if (this.openRunId === run.id && run.shot.length > 0) {
                  Image(run.shot)
                    .width('100%')
                    .height(120)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                    .border({ width: 1, color: $r('app.color.divider') })
                }
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.openRunId = this.openRunId === run.id ? '' : run.id;
              })
            }
          }, (run: RunRecord) => run.id + run.startedAt + run.kind)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  Empty() {
    EmptyHero({
      greeting: '',
      tagline: Character.tagline(this.profileName),
      promise: this.showRail() ? '' : 'Payments always ask first.',
      note: this.keyPresent ? '' : 'Add a model key to start. The key stays on this laptop.',
      titleSize: this.heroTitle(),
      bodySize: this.heroBody(),
      markSize: this.heroMark(),
      animate: true,
      interactive: true,
      body: 'laptop'
    })
  }

  @Builder
  Turn(turn: LaptopTurn, index: number) {
    if (turn.role === 'user') {
      Row() {
        Blank()
        Text(turn.text)
          .fontSize(13.5)
          .lineHeight(21)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .constraintSize({ maxWidth: '62%' })
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
    } else {
      Row({ space: 12 }) {
        HopaMark({ state: 'idle', markSize: 22, animate: false, interactive: false, body: 'laptop' })
        Column({ space: 6 }) {
          if (turn.steps.length > 0) {
            StepChips({ steps: turn.steps, dense: true })
          }
          if (ChatFormat.listItems(turn.text).length > 0) {
            if (ChatFormat.listLead(turn.text).length > 0) {
              Text(ChatFormat.listLead(turn.text))
                .fontSize(13.5)
                .lineHeight(22)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
            }
            ForEach(ChatFormat.listItems(turn.text), (line: string, lineIndex: number) => {
              Row({ space: 10 }) {
                Text(`${lineIndex + 1}`)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary'))
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor($r('app.color.primary_soft'))
                  .borderRadius(10)
                Text(line)
                  .fontSize(13.5)
                  .lineHeight(20)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (line: string, lineIndex: number) => `${lineIndex}-${line}`)
          } else {
            Text(turn.text)
              .fontSize(13.5)
              .lineHeight(22)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
          }
          Text('HOPA on this laptop')
            .fontSize(9.5)
            .fontColor($r('app.color.text_hint'))
          if (index === this.turns.length - 1 && !this.busy) {
            Text('Retry')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => {
                this.retryRun();
              })
            ResultActions({
              showOpen: false,
              onCopy: () => {
                this.copyText(turn.text);
              },
              onShare: () => {},
              onRemember: () => {}
            })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 40 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  /** The hero scales with the pane: readable on a desk, sane when narrow. */
  private heroMark(): number {
    return Math.min(108, Math.max(64, this.winWidth * 0.085));
  }

  private showSidebar(): boolean {
    return this.winWidth >= 640;
  }

  private showRail(): boolean {
    if (this.profileName === 'easy' || this.profileName === 'kid') {
      return false;
    }
    return this.winWidth >= 940;
  }

  /** Easy and Kid read larger; Power and Social stay tight. */
  private heroTitle(): number {
    if (this.profileName === 'easy' || this.profileName === 'kid') {
      return 40;
    }
    return 34;
  }

  private heroBody(): number {
    if (this.profileName === 'easy' || this.profileName === 'kid') {
      return 19;
    }
    return 16;
  }

  private tileText(): number {
    return this.profileName === 'easy' || this.profileName === 'kid' ? 15 : 13.5;
  }

  /**
   * Kid is a lock, not wallpaper: leaving it needs the parent PIN, and the
   * first visit asks for one. Without that the mode would be a lie.
   */
  private async setProfile(name: string): Promise<void> {
    if (this.profileName === 'kid' && name !== 'kid') {
      this.askPin(`mode:${name}`);
      return;
    }
    if (name === 'kid' && this.kidPin.length === 0) {
      this.pinSetMode = true;
      this.pinPrompt = true;
      this.pinDraft = '';
      this.pinError = '';
      this.pinIntent = 'mode:kid';
      return;
    }
    await this.writeProfile(name);
  }

  private async writeProfile(name: string): Promise<void> {
    this.profileName = name;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.profile = name;
    await SettingsStore.save(context, stored);
  }

  private async saveKidPin(pin: string): Promise<void> {
    this.kidPin = pin;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.kidPin = pin;
    await SettingsStore.save(context, stored);
  }

  private askPin(intent: string): void {
    this.pinSetMode = false;
    this.pinIntent = intent;
    this.pinDraft = '';
    this.pinError = '';
    this.pinPrompt = true;
  }

  private async confirmPin(): Promise<void> {
    const pin: string = this.pinDraft.trim();
    if (pin.length < 4) {
      this.pinError = 'Use at least four digits.';
      return;
    }
    if (this.pinSetMode) {
      await this.saveKidPin(pin);
      const intent: string = this.pinIntent;
      this.pinPrompt = false;
      this.pinSetMode = false;
      if (intent.startsWith('mode:')) {
        await this.writeProfile(intent.substring(5));
      }
      return;
    }
    if (pin !== this.kidPin) {
      this.pinError = 'That PIN is not right.';
      return;
    }
    const intent: string = this.pinIntent;
    this.pinPrompt = false;
    if (intent === 'settings') {
      this.settingsOpen = true;
      this.view = 'chat';
    } else if (intent.startsWith('mode:')) {
      await this.writeProfile(intent.substring(5));
    }
  }

  private openSettings(): void {
    if (this.profileName === 'kid') {
      this.askPin('settings');
      return;
    }
    this.settingsOpen = !this.settingsOpen;
  }

  @Builder
  Sidebar() {
    Column() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          HopaMark({ state: 'idle', markSize: 22, interactive: false, body: 'laptop' })
          Text('HOPA')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ left: 2 })

        Row() {
          Text('Commands')
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
          Blank()
          Text('\u203a')
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
            .opacity(0.7)
        }
        .width('100%')
        .height(26)
        .padding({ left: 8, right: 8 })
        .borderRadius(7)
        .onClick(() => {
          this.paletteOpen = true;
        })

        if (this.profileName !== 'kid') {
          Row() {
            Text('Activity')
              .fontSize(11)
              .fontColor(this.view === 'activity'
                ? $r('app.color.text_primary')
                : $r('app.color.text_hint'))
              .layoutWeight(1)
            Text(`${this.runs.length}`)
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .height(26)
          .padding({ left: 8, right: 8 })
          .borderRadius(7)
          .backgroundColor(this.view === 'activity' ? $r('app.color.surface') : Color.Transparent)
          .onClick(() => {
            this.view = this.view === 'activity' ? 'chat' : 'activity';
          })
        }

        Text('New chat')
          .fontSize(12.5)
          .fontColor($r('app.color.primary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 9, bottom: 9 })
          .backgroundColor($r('app.color.primary_soft'))
          .borderRadius(10)
          .onClick(() => {
            this.newChat();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 14, bottom: 8 })

      Scroll() {
        Column({ space: 2 }) {
          TextInput({ text: this.query, placeholder: 'Search' })
            .height(32)
            .fontSize(11.5)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(8)
            .placeholderColor($r('app.color.text_hint'))
            .margin({ bottom: 6 })
            .onChange((value: string) => {
              this.query = value;
            })

          Text('CONVERSATIONS')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.7)
            .width('100%')
            .padding({ left: 4, top: 2 })

          if (this.listedSessions().length === 0) {
            Text('No saved conversations yet.')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
              .width('100%')
              .padding({ left: 8, top: 4, bottom: 4 })
          }

          ForEach(this.listedSessions(), (session: LaptopSession) => {
            Row({ space: 6 }) {
              Text(session.title)
                .fontSize(12)
                .fontColor(session.id === this.currentId
                  ? $r('app.color.text_primary')
                  : $r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              if (session.id === this.currentId) {
                Text('\u00d7')
                  .fontSize(12)
                  .fontColor($r('app.color.text_hint'))
                  .padding({ left: 4, right: 2 })
                  .onClick(() => {
                    this.deleteSession(session.id);
                  })
              }
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 7, bottom: 7 })
            .backgroundColor(session.id === this.currentId
              ? $r('app.color.surface')
              : Color.Transparent)
            .borderRadius(9)
            .onClick(() => {
              this.openSession(session.id);
            })
          }, (session: LaptopSession) => session.id + session.title)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 8 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      Column({ space: 2 }) {
        Row() {
          Text('Settings')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
          Text('\u203a')
            .fontSize(15)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.openSettings();
        })
        if (!this.keyPresent) {
          Text('Add a model key')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: 8, top: 4 })
            .onClick(() => {
              this.settingsOpen = true;
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .border({ width: { top: 1 }, color: $r('app.color.divider') })
    }
    .width(212)
    .height('100%')
    .backgroundColor($r('app.color.surface_alt'))
    .border({ width: { right: 1 }, color: $r('app.color.divider') })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    Row() {
      if (this.showSidebar()) {
        this.Sidebar()
      }
      Column() {
        this.Header()
        if (this.view === 'activity') {
          this.ActivityPane()
        } else if (this.settingsOpen) {
          Scroll() {
            Column() {
              this.SettingsPanel()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
        } else if (this.turns.length === 0) {
          Column() {
            this.Empty()
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.turns, (turn: LaptopTurn, index: number) => {
              ListItem() {
                this.Turn(turn, index)
              }
              .padding({ top: 10, bottom: 10 })
            }, (turn: LaptopTurn, index: number) => `${index}-${turn.role}`)
            if (this.busy) {
              ListItem() {
                Row({ space: 10 }) {
                  HopaMark({ state: 'thinking', markSize: 18, interactive: false, body: 'laptop' })
                  Text('Thinking\u2026')
                    .fontSize(12)
                    .fontColor($r('app.color.text_hint'))
                }
                .width('100%')
              }
              .padding({ top: 8, bottom: 8 })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 22, right: 22 })
          .scrollBar(BarState.Off)
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(10.5)
            .fontColor($r('app.color.danger'))
            .width('100%')
            .padding({ left: 22, right: 22, bottom: 4 })
        }
        if (this.approvalOpen && !this.showRail()) {
          Column({ space: 10 }) {
            Text('HOPA asks first')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.7)
              .width('100%')
            Text(this.approvalDetail)
              .fontSize(13.5)
              .lineHeight(20)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Row({ space: 10 }) {
              Text('Not now')
                .fontSize(12.5)
                .fontColor($r('app.color.text_primary'))
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.surface_muted'))
                .borderRadius(18)
                .onClick(() => {
                  this.approvalOpen = false;
                  this.agent.approvals.answer(false);
                })
              Text('Allow')
                .fontSize(12.5)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_primary'))
                .padding({ left: 18, right: 18, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.primary'))
                .borderRadius(18)
                .onClick(() => {
                  this.approvalOpen = false;
                  this.agent.approvals.answer(true);
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 12, bottom: 6 })
          .alignItems(HorizontalAlign.Start)
        }
        if (this.settingsOpen || this.view !== 'chat') {
          Row()
            .width('100%')
            .height(0)
        } else {
        Row({ space: 10 }) {
          TextArea({ text: this.draft, placeholder: 'Ask HOPA\u2026' })
            .id('hopa-composer')
            .layoutWeight(1)
            .fontSize(13.5)
            .constraintSize({ minHeight: 44, maxHeight: 132 })
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(22)
            .padding({ left: 16, right: 16, top: 11, bottom: 11 })
            .onChange((value: string) => {
              this.draft = value;
            })
            .onKeyEvent((event: KeyEvent) => {
              if (this.handleShortcut(event)) {
                return true;
              }
              if (event.type !== KeyType.Down || event.keyCode !== 2054) {
                return;
              }
              const shift: boolean = event.getModifierKeyState
                ? event.getModifierKeyState(['shift'])
                : false;
              if (shift) {
                return;
              }
              this.send();
              return true;
            })
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(7)
              .height(13)
              .borderRadius(4)
              .backgroundColor(this.listening ? $r('app.color.danger') : $r('app.color.text_secondary'))
              .offset({ y: -2 })
            Row()
              .width(13)
              .height(1.6)
              .borderRadius(1)
              .backgroundColor(this.listening ? $r('app.color.danger') : $r('app.color.text_secondary'))
              .offset({ y: 6 })
            Row()
              .width(1.6)
              .height(3)
              .backgroundColor(this.listening ? $r('app.color.danger') : $r('app.color.text_secondary'))
              .offset({ y: 9 })
          }
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(this.listening ? $r('app.color.surface_alt') : $r('app.color.surface_muted'))
          .accessibilityText(this.listening ? 'Stop listening' : 'Talk to HOPA')
          .onClick(() => {
            this.toggleMic();
          })
          Button(this.busy ? 'Stop' : 'Send')
            .height(44)
            .fontSize(13)
            .backgroundColor(this.busy ? $r('app.color.surface_muted') : $r('app.color.primary'))
            .fontColor(this.busy ? $r('app.color.text_primary') : $r('app.color.on_primary'))
            .enabled(this.busy || this.draft.trim().length > 0)
            .onClick(() => {
              if (this.busy) {
                this.chat.cancel();
              } else {
                this.send();
              }
            })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 8, bottom: 16 })
        }
      }
      .layoutWeight(1)
      .height('100%')
      if (this.showRail()) {
        ChatRail({
          lastQuestion: this.lastQuestion,
          lastLatency: this.lastLatency,
          lastTokens: this.lastTokens,
          hasTurns: this.turns.length > 0,
          bridgeLive: this.bridgeLive,
          approvalOpen: this.approvalOpen,
          approvalDetail: this.approvalDetail,
          approvalFrame: this.approvalFrame,
          onAllow: () => {
            this.approvalOpen = false;
            this.agent.approvals.answer(true);
          },
          onDeny: () => {
            this.approvalOpen = false;
            this.agent.approvals.answer(false);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.winWidth = Number(newValue.width.toString());
    })
      if (this.pinPrompt) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            // A scrim that swallows taps: leaving Kid is deliberate.
          })
        Column({ space: 10 }) {
          Text(this.pinSetMode ? 'Choose a parent PIN' : 'Grown-ups only')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.pinSetMode
            ? 'Leaving Kid later will ask for this PIN.'
            : 'Enter the parent PIN to carry on.')
            .fontSize(11.5)
            .lineHeight(16)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({ text: this.pinDraft, placeholder: 'PIN' })
            .type(InputType.Number)
            .maxLength(8)
            .height(38)
            .fontSize(14)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(9)
            .onChange((value: string) => {
              this.pinDraft = value;
            })
            .onSubmit(() => {
              this.confirmPin();
            })
          if (this.pinError.length > 0) {
            Text(this.pinError)
              .fontSize(11)
              .fontColor($r('app.color.danger'))
              .width('100%')
          }
          Row({ space: 8 }) {
            Text('Cancel')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(12)
              .onClick(() => {
                this.pinPrompt = false;
                this.pinSetMode = false;
              })
            Text('Okay')
              .fontSize(12.5)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(12)
              .onClick(() => {
                this.confirmPin();
              })
          }
          .width('100%')
        }
        .width(300)
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') })
        .alignItems(HorizontalAlign.Start)
      }
      if (this.paletteOpen) {
        CommandPalette({
          onNewChat: () => {
            this.newChat();
          },
          onSettings: () => {
            this.settingsOpen = true;
          },
          onClose: () => {
            this.paletteOpen = false;
            this.focusRoot();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .id('hopa-root')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      return this.handleShortcut(event);
    })
  }
}
