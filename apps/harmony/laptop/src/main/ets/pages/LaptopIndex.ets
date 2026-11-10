import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { HopaMark, EmptyHero, ResultActions, StepChips, ChatFormat, KeyStore, SettingsStore, StoredSettings } from '@hopa/app';
import { LaptopChat, LaptopTurn } from '../services/LaptopChat';
import { LaptopAgent } from '../services/LaptopAgent';

import { LaptopSessions, LaptopSession } from '../services/LaptopSessions';
import { LaptopPhoneLink, RemoteSession, RemoteTurn } from '../services/LaptopPhoneLink';
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
  @State remoteSessions: RemoteSession[] = [];
  @State remoteOpen: boolean = false;
  @State remoteId: string = '';
  @State remoteTitle: string = '';
  @State remoteTurns: RemoteTurn[] = [];
  @State linkUrl: string = '';
  @State linkKey: string = '';
  @State linkStatus: string = '';
  @State linkConfigured: boolean = false;
  private link: LaptopPhoneLink = new LaptopPhoneLink();
  @State currentId: string = '';
  private store: LaptopSessions = new LaptopSessions();
  private win: window.Window | undefined = undefined;
  @State maximized: boolean = false;
  @StorageProp('hopa.decorHidden') decorHidden: boolean = false;
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
    LaptopPhoneLink.load(context).then((link: LaptopPhoneLink) => {
      this.link = link;
      const injectedUrl: string = AppStorage.get<string>('hopa.laptop.linkUrl') ?? '';
      const injectedKey: string = AppStorage.get<string>('hopa.laptop.linkKey') ?? '';
      if (injectedUrl.length > 0 || injectedKey.length > 0) {
        this.link.url = injectedUrl.length > 0 ? injectedUrl : link.url;
        this.link.key = injectedKey.length > 0 ? injectedKey : link.key;
        AppStorage.setOrCreate<string>('hopa.laptop.linkUrl', '');
        AppStorage.setOrCreate<string>('hopa.laptop.linkKey', '');
        this.link.save(context);
      }
      this.linkUrl = this.link.url;
      this.linkKey = this.link.key;
      this.linkConfigured = this.link.isConfigured();
      if (this.linkConfigured) {
        this.fetchPhone();
      }
    }).catch(() => {
      // No phone link yet.
    });
    window.getLastWindow(context).then((win: window.Window) => {
      this.win = win;
    }).catch(() => {
      // The system bar remains if the window cannot be reached.
    });
    LaptopSessions.load(context).then((store: LaptopSessions) => {
      this.store = store;
      this.store.prune();
      this.store.save(context);
      const session: LaptopSession = store.current();
      this.chat.turns = session.turns.slice();
      this.turns = session.turns.slice();
      this.lastLatency = session.lastLatency;
      this.lastTokens = session.lastTokens;
      this.refreshSessions();
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
    const shown: LaptopSession[] = [];
    for (const session of this.sessions) {
      if (session.turns.length > 0) {
        shown.push(session);
      }
    }
    return shown;
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

  private async fetchPhone(): Promise<void> {
    this.linkStatus = 'Reading?';
    const ok: boolean = await this.link.fetch();
    if (ok) {
      const withTurns: RemoteSession[] = [];
      for (const session of this.link.sessions) {
        if (session.turns.length > 0) {
          withTurns.push(session);
        }
      }
      withTurns.sort((a: RemoteSession, b: RemoteSession) => b.updated - a.updated);
      this.remoteSessions = withTurns;
      this.linkStatus = 'Connected';
    } else {
      this.remoteSessions = [];
      this.linkStatus = this.link.error;
    }
  }

  private async savePhoneLink(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    this.link.url = this.linkUrl;
    this.link.key = this.linkKey;
    await this.link.save(context);
    this.linkConfigured = this.link.isConfigured();
    await this.fetchPhone();
  }

  private openRemote(session: RemoteSession): void {
    this.settingsOpen = false;
    this.remoteOpen = true;
    this.remoteId = session.id;
    this.remoteTitle = session.title;
    this.remoteTurns = session.turns;
    this.paletteOpen = false;
  }

  private focusRoot(): void {
    try {
      focusControl.requestFocus('hopa-root');
    } catch (error) {
      // Focus control is best effort.
    }
  }

  private closeRemote(): void {
    this.remoteOpen = false;
    this.remoteId = '';
    this.remoteTurns = [];
    this.remoteTitle = '';
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
    this.closeRemote();
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
    this.store.remove(id);
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
    if (injectedEndpoint.length === 0 && injectedModel.length === 0 && injectedKey.length === 0) {
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
    this.store.commit(this.chat.turns, this.chat.lastLatencyMs, this.chat.lastTokens);
    this.store.save(context);
    this.refreshSessions();
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
  Header() {
    Row({ space: 12 }) {
      HopaMark({ state: 'idle', markSize: 26, interactive: false })
      Column({ space: 1 }) {
        Text(this.remoteOpen ? this.remoteTitle : this.currentTitle)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(-0.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 320 })
        Text(this.remoteOpen ? 'Read-only copy from your phone' : 'Running on this laptop')
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
        Text('PHONE SESSIONS')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')

        Text('A read-only copy of the conversations on your phone, through the PC bridge. This key can only read them; it cannot tap or type on the phone.')
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        this.FieldLabel('Bridge address')
        TextInput({ text: this.linkUrl, placeholder: 'http://127.0.0.1:8766' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.linkUrl = value;
          })

        this.FieldLabel('Read-only key')
        TextInput({ text: this.linkKey, placeholder: 'from the bridge output' })
          .height(38)
          .fontSize(12.5)
          .type(InputType.Password)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.linkKey = value;
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
              this.savePhoneLink();
            })
          if (this.linkStatus.length > 0) {
            Text(this.linkStatus)
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
  Empty() {
    EmptyHero({
      greeting: '',
      tagline: 'Your agent. Ask for anything.',
      promise: this.showRail() ? '' : 'Payments always ask first.',
      note: this.keyPresent ? '' : 'Add a model key to start. The key stays on this laptop.',
      titleSize: 34,
      bodySize: 16,
      markSize: this.heroMark(),
      animate: true,
      interactive: true
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
        HopaMark({ state: 'idle', markSize: 22, animate: false, interactive: false })
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
    return this.winWidth >= 940;
  }

  @Builder
  Sidebar() {
    Column() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          HopaMark({ state: 'idle', markSize: 22, interactive: false })
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
                .fontColor(session.id === this.currentId && !this.remoteOpen
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
            .backgroundColor(session.id === this.currentId && !this.remoteOpen
              ? $r('app.color.surface')
              : Color.Transparent)
            .borderRadius(9)
            .onClick(() => {
              this.openSession(session.id);
            })
          }, (session: LaptopSession) => session.id + session.title)

          if (this.remoteSessions.length > 0) {
            Text(`FROM YOUR PHONE \u00b7 ${this.remoteSessions.length}`)
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.7)
              .width('100%')
              .padding({ left: 4, top: 16 })

            ForEach(this.remoteSessions.slice(0, 20), (session: RemoteSession) => {
              Row({ space: 6 }) {
                Text(session.title)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text('\u2192')
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .backgroundColor(this.remoteOpen && this.remoteId === session.id
                ? $r('app.color.surface')
                : Color.Transparent)
              .borderRadius(8)
              .onClick(() => {
                this.openRemote(session);
              })
            }, (session: RemoteSession) => 'phone-' + session.id + session.title)

            if (this.remoteSessions.length > 20) {
              Text('+' + (this.remoteSessions.length - 20) + ' more on the phone')
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
                .padding({ left: 8, top: 4 })
            }
          }
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
          this.settingsOpen = !this.settingsOpen;
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
        if (this.settingsOpen) {
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
        } else if (this.remoteOpen) {
          List() {
            ForEach(this.remoteTurns, (turn: RemoteTurn, index: number) => {
              ListItem() {
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
                    HopaMark({ state: 'idle', markSize: 22, animate: false, interactive: false })
                    Text(turn.text)
                      .fontSize(13.5)
                      .lineHeight(22)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                      .copyOption(CopyOptions.LocalDevice)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                  .padding({ right: 40 })
                }
              }
              .padding({ top: 10, bottom: 10 })
            }, (turn: RemoteTurn, index: number) => `${this.remoteId}-${index}-${turn.role}`)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 22, right: 22 })
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
                  HopaMark({ state: 'thinking', markSize: 18, interactive: false })
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
        if (this.settingsOpen) {
          Row()
            .width('100%')
            .height(0)
        } else if (this.remoteOpen) {
          Row({ space: 10 }) {
            Text('Read-only copy from your phone. Reply there.')
              .fontSize(11.5)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
            Text('Close')
              .fontSize(12)
              .fontColor($r('app.color.primary'))
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor($r('app.color.primary_soft'))
              .borderRadius(14)
              .onClick(() => {
                this.closeRemote();
              })
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 8, bottom: 16 })
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
          Button('Send')
            .height(44)
            .fontSize(13)
            .backgroundColor($r('app.color.primary'))
            .fontColor($r('app.color.on_primary'))
            .enabled(!this.busy && this.draft.trim().length > 0)
            .onClick(() => {
              this.send();
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
          hasTurns: this.turns.length > 0
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.winWidth = Number(newValue.width.toString());
    })
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
