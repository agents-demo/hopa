import { common } from '@kit.AbilityKit';
import { Action, ChatSession, Screen } from '@hopa/core';
import { AgentService } from '../services/AgentService';
import { AppBoot } from '../services/AppBoot';
import { ApprovalContent, ApprovalContentBuilder } from '../services/ApprovalContent';
import { ChatsSheet } from '../navigation/ChatsSheet';
import { pageTitle } from '../navigation/PageTitles';
import { TabIcon } from '../navigation/TabIcon';
import { ApprovalSheet } from './chat/ApprovalSheet';
import { PageRouter } from './PageRouter';

/**
 * The app shell: one page at a time, a bottom bar for the four primary areas,
 * and a Chats sheet for history. Settings and secondary screens live in Tools.
 */
@Entry
@Component
struct Index {
  @State activePage: string = 'chat';
  @State chatsOpen: boolean = false;
  @State chatSessions: ChatSession[] = [];
  @State chatTitle: string = 'Chat';
  @State approvalOpen: boolean = false;
  @State approvalTitle: string = '';
  @State approvalMessage: string = '';
  @State approvalPayment: boolean = false;
  private agentOpenedBrowser: boolean = false;
  private titleTimer: number = -1;
  private previousPage: string = 'chat';
  private approvalResolve: ((allow: boolean) => void) | undefined = undefined;

  aboutToAppear(): void {
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
    this.refreshChats();
    this.titleTimer = setInterval(() => {
      this.syncTitle();
    }, 700);
    this.initialize();
  }

  aboutToDisappear(): void {
    if (this.titleTimer >= 0) {
      clearInterval(this.titleTimer);
      this.titleTimer = -1;
    }
  }

  private refreshChats(): void {
    this.chatSessions = AgentService.get().conversations.all().slice();
    this.syncTitle();
  }

  private syncTitle(): void {
    const session: ChatSession | undefined = AgentService.get().conversations.current();
    let title: string = 'HOPA';
    if (session !== undefined &&
      session.entries.length > 0 &&
      session.title.length > 0 &&
      session.title !== 'New chat') {
      title = session.title;
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
      this.previousPage = this.activePage;
      this.activePage = key;
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
    this.approvalOpen = true;
    return new Promise<boolean>((resolve: (allow: boolean) => void) => {
      this.approvalResolve = resolve;
    });
  }

  private answerApproval(allow: boolean): void {
    this.approvalOpen = false;
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
    return this.activePage === 'chat' ||
      this.activePage === 'more' ||
      this.activePage === 'settings';
  }

  private tabActive(key: string): boolean {
    if (key === 'chat') {
      return this.activePage === 'chat';
    }
    if (key === 'settings') {
      return this.activePage === 'settings';
    }
    return this.activePage !== 'chat' && this.activePage !== 'settings';
  }

  @Builder
  Tab(label: string, key: string) {
    Column({ space: 3 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(48)
          .height(28)
          .borderRadius(14)
          .backgroundColor(this.tabActive(key) ? $r('app.color.primary_soft') : Color.Transparent)
        TabIcon({ kind: key, active: this.tabActive(key) })
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
      if (this.activePage === 'chat') {
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
        .onClick(() => {
          this.openChats();
        })
        Text(this.chatTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
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
        .onClick(() => {
          AgentService.get().conversations.newChat();
          this.refreshChats();
          this.go('chat');
        })
      } else {
        Text(pageTitle(this.activePage))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 12 })
  }

  @Builder
  BottomBar() {
    Row() {
      this.Tab('Chat', 'chat')
      this.Tab('Tools', 'more')
      this.Tab('Settings', 'settings')
    }
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
      onNewChat: () => {
        AgentService.get().conversations.newChat();
        this.refreshChats();
        this.go('chat');
      },
      onSelect: (id: string) => {
        AgentService.get().conversations.select(id);
        this.refreshChats();
        this.go('chat');
      },
      onDelete: (id: string) => {
        AgentService.get().conversations.delete(id);
        this.refreshChats();
      },
      onClose: () => {
        this.chatsOpen = false;
      }
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
        this.TopBar()
        Column() {
          PageRouter({
            activePage: this.activePage,
            onNavigate: (key: string) => {
              this.go(key);
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        this.BottomBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg'))

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
