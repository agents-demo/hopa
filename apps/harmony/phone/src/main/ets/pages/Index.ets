import { common } from '@kit.AbilityKit';
import { Action, ChatSession, Screen } from '@hopa/core';
import { AgentService } from '../services/AgentService';
import { AppBoot } from '../services/AppBoot';
import { ApprovalContent, ApprovalContentBuilder } from '../services/ApprovalContent';
import { ChatsSheet } from '../navigation/ChatsSheet';
import { pageTitle } from '../navigation/PageTitles';
import { TabIcon } from '../navigation/TabIcon';
import { ApprovalSheet } from './chat/ApprovalSheet';
import { HopaMark } from './chat/HopaMark';
import { PageRouter } from './PageRouter';
import { Haptics } from '../services/Haptics';
import { SettingsStore } from '../services/SettingsStore';
import { VisualStyle } from '../services/VisualStyle';
import { BridgeMonitor } from '../services/BridgeMonitor';
import { IntentInbox } from '../services/IntentInbox';
import { KeyboardAvoidMode as HostKeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { window } from '@kit.ArkUI';

/**
 * The app shell: one page at a time, a bottom bar for the four primary areas,
 * and a Chats sheet for history. Settings and secondary screens live in Tools.
 */
@Entry
@Component
struct Index {
  @State activePage: string = 'chat';
  @State keyboardVisible: boolean = false;
  @State chatsOpen: boolean = false;
  @State chatSessions: ChatSession[] = [];
  @State chatTitle: string = '';
  @State approvalOpen: boolean = false;
  @State approvalTitle: string = '';
  @State approvalMessage: string = '';
  @State approvalPayment: boolean = false;
  /** Empty unless the last run (or setup) needs attention. */
  @StorageLink('hopa.problem') problem: string = '';
  @StorageLink('hopa.bridgeOnline') bridgeOnline: boolean = true;
  /** Set by a home sheet: hide the shell chrome while it is focused. */
  @StorageLink('hopa.focus') focusMode: boolean = false;
  @StorageLink('hopa.style') styleName: string = 'calm';
  @State profileName: string = 'everyday';
  private agentOpenedBrowser: boolean = false;
  private titleTimer: number = -1;
  private previousPage: string = 'chat';
  private approvalResolve: ((allow: boolean) => void) | undefined = undefined;

  aboutToAppear(): void {
    try {
      this.getUIContext().setKeyboardAvoidMode(HostKeyboardAvoidMode.RESIZE);
    } catch (error) {
      // Older runtimes use the default avoidance mode.
    }
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        win.on('keyboardHeightChange', (height: number) => {
          this.keyboardVisible = height > 0;
        });
      }).catch(() => {
        // Keyboard state is cosmetic; the page still works.
      });
    } catch (error) {
      // Best effort.
    }
    const service = AgentService.get();
    service.setAbilityContext(getContext(this) as common.UIAbilityContext);
    service.setSiteOpener((url: string) => this.openSite(url));
    service.setRunDoneListener(() => {
      this.finishWebRun();
    });
    service.approvals.setHandler((action: Action, screen: Screen | undefined) => {
      return this.askApproval(action, screen);
    });
    service.pageLinks.setOpener((url: string) => {
      service.browser.requestUrl(url);
      this.previousPage = this.activePage;
      this.activePage = 'browser';
      this.chatsOpen = false;
    });
    SettingsStore.load(getContext(this)).then((stored) => {
      AppStorage.setOrCreate<string>(VisualStyle.KEY, stored.style);
      AppStorage.setOrCreate<string>('hopa.profile', stored.profile);
    }).catch(() => {
      // The default look is fine when settings cannot be read.
    });
    BridgeMonitor.start();
    this.refreshChats();
    this.titleTimer = setInterval(() => {
      this.syncTitle();
    }, 700);
    this.initialize();
  }

  aboutToDisappear(): void {
    BridgeMonitor.stop();
    if (this.titleTimer >= 0) {
      clearInterval(this.titleTimer);
      this.titleTimer = -1;
    }
  }

  private refreshChats(): void {
    this.chatSessions = AgentService.get().conversations.all().slice();
    this.syncTitle();
  }

  private style(): VisualStyle {
    return VisualStyle.of(this.styleName);
  }

  /** Everyday keeps the chat as home; the other profiles get their own. */
  private customHome(): boolean {
    return this.profileName !== 'everyday';
  }

  /** Profiles with a custom home land there; Everyday lands in the chat. */
  onProfileChange(): void {
    if (this.customHome()) {
      if (this.activePage === 'chat') {
        this.activePage = 'home';
      }
    } else if (this.activePage === 'home') {
      this.activePage = 'chat';
    }
  }

  private syncTitle(): void {
    const session: ChatSession | undefined = AgentService.get().conversations.current();
    let title: string = '';
    if (session !== undefined &&
      session.entries.length > 0 &&
      session.title.length > 0 &&
      session.title !== 'New chat') {
      title = session.title;
    }
    const incoming: string = IntentInbox.take();
    if (incoming.length > 0) {
      AppStorage.setOrCreate<string>('hopa.pendingGoal', incoming);
      this.previousPage = this.activePage;
      this.activePage = 'chat';
    }
    // @StorageLink + @Watch was not reliable here; poll the shell's copy.
    const profile: string = AppStorage.get<string>('hopa.profile') ?? 'everyday';
    if (profile !== this.profileName) {
      this.profileName = profile;
      this.onProfileChange();
    }
    if (title !== this.chatTitle) {
      this.chatTitle = title;
    }
  }

  private openChats(): void {
    this.refreshChats();
    this.chatsOpen = true;
  }

  private go(key: string): void {
    if (key !== this.activePage) {
      animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.previousPage = this.activePage;
      this.activePage = key;
      });
    }
    this.chatsOpen = false;
  }

  private back(): void {
    const target: string = this.previousPage === this.activePage
      ? 'chat'
      : this.previousPage;
    this.previousPage = 'chat';
    this.activePage = target;
  }

  /** Asks in the shell, so the sheet can appear over Browser or Chat. */
  private askApproval(action: Action, screen: Screen | undefined): Promise<boolean> {
    const content: ApprovalContent =
      ApprovalContentBuilder.describe(AgentService.get().policy, action, screen);
    this.approvalTitle = content.title;
    this.approvalMessage = content.message;
    this.approvalPayment = content.payment;
    Haptics.attention();
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.approvalOpen = true;
    });
    return new Promise<boolean>((resolve: (allow: boolean) => void) => {
      this.approvalResolve = resolve;
    });
  }

  private answerApproval(allow: boolean): void {
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseIn }, () => {
      this.approvalOpen = false;
    });
    const resolve: ((allow: boolean) => void) | undefined = this.approvalResolve;
    this.approvalResolve = undefined;
    if (resolve !== undefined) {
      resolve(allow);
    }
  }

  /**
   * Switches to the Browser page for an agent navigation and waits until the
   * WebView is attached. This lets a short Chat prompt operate a site without
   * the user opening the Browser first.
   */
  private async openSite(url: string): Promise<boolean> {
    this.agentOpenedBrowser = true;
    AgentService.get().browser.requestUrl(url);
    this.previousPage = this.activePage;
    this.activePage = 'browser';
    this.chatsOpen = false;
    for (let attempt = 0; attempt < 300; attempt++) {
      if (AgentService.get().browser.isReady()) {
        return true;
      }
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 100);
      });
    }
    return false;
  }

  /**
   * Returns to Chat when the run HOPA started on a page is finished, so the
   * answer is visible without the user guessing how long to wait. A page the
   * user opened by hand is left alone.
   */
  private finishWebRun(): void {
    if (!this.agentOpenedBrowser) {
      return;
    }
    this.agentOpenedBrowser = false;
    if (this.activePage === 'browser') {
      this.activePage = 'chat';
      this.chatsOpen = false;
    }
  }

  private isTopLevel(): boolean {
    if (this.activePage === 'chat') {
      return !this.customHome();
    }
    return this.activePage === 'home' ||
      this.activePage === 'activity' ||
      this.activePage === 'capabilities';
  }

  private activityChild(): boolean {
    return this.activePage === 'runs' ||
      this.activePage === 'screens' ||
      this.activePage === 'plans';
  }

  private tabActive(key: string): boolean {
    if (key === 'home') {
      return this.activePage === 'home' || this.activePage === 'chat';
    }
    if (key === 'chat') {
      return this.activePage === 'chat';
    }
    if (key === 'easyhistory') {
      return this.activePage === 'easyhistory';
    }
    if (key === 'settings') {
      return this.activePage === 'settings';
    }
    if (key === 'activity') {
      return this.activePage === 'activity' || this.activityChild();
    }
    if (key === 'capabilities') {
      const otherTop: boolean = this.activePage === 'chat' ||
        this.activePage === 'home' ||
        this.activePage === 'activity' ||
        this.activePage === 'browser' ||
        this.activityChild();
      return !otherTop;
    }
    return false;
  }

  @Builder
  Tab(label: string, key: string, iconKey: string = key) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(48)
          .height(28)
          .borderRadius(14)
          .backgroundColor(this.tabActive(key) ? $r('app.color.primary_soft') : Color.Transparent)
          .animation({ duration: 160, curve: Curve.EaseOut })
        TabIcon({ kind: iconKey, active: this.tabActive(key) })
      }
      .width(48)
      .height(28)
      Text(label)
        .fontSize(11)
        .fontWeight(this.tabActive(key) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tabActive(key) ? $r('app.color.primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.go(key);
    })
  }

  @Builder
  TopBar() {
    Row({ space: 8 }) {
      if (!this.isTopLevel()) {
        Text('←')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.back();
          })
      }
      if (this.activePage === 'chat' || this.activePage === 'home') {
        if (this.profileName === 'everyday') {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(19)
            .height(19)
            .borderRadius(9.5)
            .border({ width: 1.8, color: $r('app.color.text_primary') })
          Column()
            .width(1.8)
            .height(5)
            .borderRadius(0.9)
            .backgroundColor($r('app.color.text_primary'))
            .offset({ y: -2 })
          Row()
            .width(4.5)
            .height(1.8)
            .borderRadius(0.9)
            .backgroundColor($r('app.color.text_primary'))
            .offset({ x: 2, y: 0.5 })
        }
        .width(44)
        .height(44)
        .accessibilityText('Chat history')
        .onClick(() => {
          this.openChats();
        })
        }
        if (this.chatTitle.length > 0 && this.activePage === 'chat') {
          Text(this.chatTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        } else {
          Row().layoutWeight(1)
        }
        // Chat stays clean; the only header signal is a real problem.
        if (this.problem.length > 0) {
          Row({ space: 5 }) {
            HopaMark({ state: 'error', markSize: 20, interactive: false })
            Text('Problem')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.danger'))
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#14C0392B')
          .borderRadius(10)
          .margin({ right: 6 })
          .onClick(() => {
            this.go('runs');
          })
        }
        if (this.profileName === 'everyday') {
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor($r('app.color.primary_soft'))
          Row().width(14).height(2).borderRadius(1).backgroundColor($r('app.color.primary'))
          Row().width(2).height(14).borderRadius(1).backgroundColor($r('app.color.primary'))
        }
        .width(40)
        .height(44)
        .accessibilityText('New chat')
        .onClick(() => {
          AgentService.get().conversations.newChat();
          this.refreshChats();
          this.go('chat');
        })
        }
      } else {
        Text(pageTitle(this.activePage))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        if (this.activePage === 'capabilities') {
          Text('Settings')
            .fontSize(12)
            .fontColor($r('app.color.primary'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.primary_soft'))
            .borderRadius(8)
            .accessibilityText('Settings')
            .onClick(() => {
              this.go('settings');
            })
        }
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 12 })
  }

  @Builder
  BottomBar() {
    Row() {
      if (this.profileName === 'kid') {
        this.Tab('Home', 'home', 'chat')
      } else if (this.profileName === 'easy') {
        this.Tab('Talk', 'home', 'chat')
        this.Tab('History', 'easyhistory')
        this.Tab('Settings', 'settings')
      } else {
        this.Tab(this.customHome() ? 'Home' : 'Chat', this.customHome() ? 'home' : 'chat', 'chat')
        this.Tab('Activity', 'activity')
        this.Tab('Capabilities', 'capabilities')
      }
    }
    .width('100%')
    .height(58)
    .backgroundColor(`#D9${this.style().bg.substring(1)}`)
    .backgroundBlurStyle(BlurStyle.Thin)
    .width('100%')
    .height(64)
    .padding({ left: 6, right: 6, top: 4, bottom: 6 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  ChatsPanel() {
    ChatsSheet({
      sessions: this.chatSessions,
      currentId: AgentService.get().conversations.currentId(),
      onNewChat: () => { AgentService.get().conversations.newChat(); this.refreshChats(); this.go('chat'); },
      onSelect: (id: string) => { AgentService.get().conversations.select(id); this.refreshChats(); this.go('chat'); },
      onDelete: (id: string) => { AgentService.get().conversations.delete(id); this.refreshChats(); },
      onClose: () => { this.chatsOpen = false; }
    })
  }

  private async initialize(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const firstRun: boolean = await AppBoot.start(AgentService.get(), context);
    this.refreshChats();
    if (firstRun) {
      this.activePage = 'welcome';
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // A custom home owns the whole screen: no clock, no "+", no Everyday
        // chat entry from here.
        if (!this.focusMode && this.activePage !== 'home' && this.activePage !== 'easyhistory') {
          this.TopBar()
        }
        if (!this.focusMode && !this.bridgeOnline && AgentService.get().isBridgeConfigured()) {
          Row({ space: 8 }) {
            Text('PC bridge offline')
              .fontSize(11)
              .fontColor($r('app.color.danger'))
            Text('Retry')
              .fontSize(11)
              .fontColor($r('app.color.primary'))
              .onClick(() => {
                BridgeMonitor.checkNow();
              })
          }
          .width('100%')
          .height(28)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#14C0392B')
        }
        Column() {
          PageRouter({
            activePage: this.activePage,
            onNavigate: (key: string) => {
              this.go(key);
            },
            onOpenChat: (goal: string, voice: boolean) => {
              if (goal.length > 0) {
                AppStorage.setOrCreate<string>('hopa.pendingGoal', goal);
              }
              AppStorage.setOrCreate<boolean>('hopa.autovoice', voice);
              this.previousPage = this.activePage;
              this.activePage = 'chat';
            },
            onOpenRuns: () => {
              this.go('runs');
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        // Easy is calm: no tab bar, just two quiet links on the home screen.
        if (this.activePage !== 'browser' && !this.keyboardVisible && !this.focusMode &&
          this.profileName !== 'easy' && this.profileName !== 'kid') {
          this.BottomBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.style().bg)

      if (this.approvalOpen) {
        ApprovalSheet({
          title: this.approvalTitle,
          message: this.approvalMessage,
          payment: this.approvalPayment,
          onAllow: () => {
            this.answerApproval(true);
          },
          onDeny: () => {
            this.answerApproval(false);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet(this.chatsOpen, this.ChatsPanel(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.surface'),
      onDisappear: () => {
        this.chatsOpen = false;
      }
    })
  }
}
