import { Context, common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { ChatSession } from '@hopa/core';
import { AgentService } from '../services/AgentService';
import { SettingsStore, StoredSettings } from '../services/SettingsStore';
import { AppLauncher } from '../services/AppLauncher';
import { AppsPage } from './apps/AppsPage';
import { ChatPage } from './chat/ChatPage';
import { BrowserPage } from './browser/BrowserPage';
import { McpServersPage } from './mcp/McpServersPage';
import { MemoryPage } from './memory/MemoryPage';
import { ModelsPage } from './models/ModelsPage';
import { PhonePage } from './phone/PhonePage';
import { SourcePage } from './source/SourcePage';
import { UsagePage } from './usage/UsagePage';
import { RunsPage } from './runs/RunsPage';
import { PlansPage } from './plans/PlansPage';
import { SettingsPage } from './settings/SettingsPage';
import { ScreensPage } from './tools/ScreensPage';
import { SelfCheckPage } from './tools/SelfCheckPage';
import { FilesPage } from './tools/FilesPage';
import { LicensePage } from './tools/LicensePage';
import { AboutPage } from './tools/AboutPage';
import { WelcomePage } from './tools/WelcomePage';

@Entry
@Component
struct Index {
  @State activePage: string = 'chat';
  @State menuOpen: boolean = false;
  @State chatSessions: ChatSession[] = [];

  private refreshChats(): void {
    this.chatSessions = AgentService.get().conversations.all().slice();
  }


  aboutToAppear(): void {
    const service = AgentService.get();
    service.setAbilityContext(getContext(this) as common.UIAbilityContext);
    this.initialize();
  }

  private async initialize(): Promise<void> {
    await this.bootstrapSettings();
    await this.loadMemory();
    await this.loadSkills();
    await this.loadRuns();
    await this.loadSchedules();
    AgentService.get().setUiLauncher(
      new AppLauncher(getContext(this) as common.UIAbilityContext)
    );
    AgentService.get().startScheduler();
    if (await SettingsStore.needsWelcome(getContext(this) as Context)) {
      this.activePage = 'welcome';
      await SettingsStore.markWelcomeSeen(getContext(this) as Context);
    }
  }

  /**
   * Applies the saved switches and configures the bundled development key.
   * The key is read from rawfile and never stored.
   */
  private async bootstrapSettings(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      AgentService.get().setNetworkEnabled(stored.network);
      AgentService.get().setAutonomous(stored.autonomous);
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        AgentService.get().configureBridge(stored.bridgeUrl, stored.bridgeToken);
      }
    } catch (error) {
      // First run or an unreadable store: keep the defaults.
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const data = await context.resourceManager.getRawFileContent('deepseek.key');
      const key = buffer.from(data).toString('utf8').trim();
      if (key.length >= 10) {
        AgentService.get().configureModel(
          'deepseek',
          'https://api.deepseek.com/v1',
          key,
          'deepseek-v4-flash',
          6
        );
      }
    } catch (error) {
      // No bundled key: a normal first run.
    }
  }

  private async loadSchedules(): Promise<void> {
    await AgentService.get().loadSchedules(getContext(this) as Context);
    AgentService.get().startScheduler();
  }

  private async loadMemory(): Promise<void> {
    try {
      await AgentService.get().memory.load(getContext(this) as Context);
    } catch (error) {
      // First run: no memory yet.
    }
  }

  private async loadSkills(): Promise<void> {
    try {
      await AgentService.get().skills.load(getContext(this) as Context);
    } catch (error) {
      // First run: no skills yet.
    }
  }

  private async loadRuns(): Promise<void> {
    try {
      await AgentService.get().loadRuns(getContext(this) as Context);
    } catch (error) {
      // First run: no history yet.
    }
  }

  @Builder
  MoreToolsPage() {
    Column({ space: 10 }) {
      Text('More')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('The screens Mika keeps in its drawer that do not fit above.')
        .fontSize(12)
        .fontColor('#666666')
      this.ToolRow('Source', 'Model, backend and observation source', 'source')
      this.ToolRow('MCP servers', 'What runs on the phone and what runs on the PC', 'mcpservers')
      this.ToolRow('Files', 'Exported data on this device', 'files')
      this.ToolRow('License', 'Apache-2.0 and third-party notices', 'license')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ToolRow(title: string, subtitle: string, key: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
        Text(subtitle)
          .fontSize(11)
          .fontColor('#999999')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F7F8FA')
    .borderRadius(10)
    .onClick(() => {
      this.activePage = key;
    })
  }

  private pageTitle(): string {
    if (this.activePage === 'chat') {
      return 'Chat';
    }
    if (this.activePage === 'plans') {
      return 'Plans';
    }
    if (this.activePage === 'memory') {
      return 'Memory';
    }
    if (this.activePage === 'browser') {
      return 'Browser';
    }
    if (this.activePage === 'screens') {
      return 'Screens';
    }
    if (this.activePage === 'settings') {
      return 'Settings';
    }
    if (this.activePage === 'about') {
      return 'About';
    }
    if (this.activePage === 'run') {
      return 'Run';
    }
    if (this.activePage === 'selfcheck') {
      return 'Self-check';
    }
    if (this.activePage === 'files') {
      return 'Files';
    }
    if (this.activePage === 'license') {
      return 'License';
    }
    if (this.activePage === 'welcome') {
      return 'Welcome';
    }
    if (this.activePage === 'apps') {
      return 'Apps';
    }
    if (this.activePage === 'runs') {
      return 'Runs and batches';
    }
    if (this.activePage === 'models') {
      return 'Models';
    }
    if (this.activePage === 'usage') {
      return 'Usage';
    }
    if (this.activePage === 'phone') {
      return 'Phone setup';
    }
    if (this.activePage === 'source') {
      return 'Source';
    }
    if (this.activePage === 'mcpservers') {
      return 'MCP servers';
    }
    return 'HOPA';
  }

  @Builder
  DrawerItem(title: string, key: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(this.activePage === key ? '#0A59F7' : '#333333')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.activePage === key ? '#EAF1FF' : '#00000000')
    .borderRadius(8)
    .onClick(() => {
        this.activePage = key;
      this.menuOpen = false;
    })
  }

  @Builder
  Drawer() {
    Column({ space: 6 }) {
      Text('HOPA')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 12, top: 8, bottom: 2 })
      Button('+ New chat')
        .fontSize(13)
        .height(34)
        .width('100%')
        .backgroundColor('#0A59F7')
        .onClick(() => {
          AgentService.get().conversations.newChat();
          this.refreshChats();
          this.activePage = 'chat';
          this.menuOpen = false;
        })
      Text('CONVERSATIONS')
        .fontSize(10)
        .fontColor('#999999')
        .padding({ left: 12, top: 4, bottom: 2 })
      ForEach(this.chatSessions, (session: ChatSession, index: number) => {
        Row({ space: 6 }) {
          Text(session.title)
            .fontSize(13)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('x')
            .fontSize(13)
            .fontColor('#B42318')
            .padding({ left: 8, right: 4 })
            .onClick(() => {
              AgentService.get().conversations.delete(session.id);
              this.refreshChats();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(session.id === AgentService.get().conversations.currentId() ? '#EAF1FF' : '#00000000')
        .onClick(() => {
          AgentService.get().conversations.select(session.id);
          this.refreshChats();
          this.activePage = 'chat';
          this.menuOpen = false;
        })
      }, (session: ChatSession, index: number) => `${session.id}-${session.updatedAt}`)
      Divider()
        .margin({ top: 4, bottom: 4 })
      Column({ space: 1 }) {
        this.DrawerItem('Chat', 'chat')
        this.DrawerItem('Plans', 'plans')
        this.DrawerItem('Memory', 'memory')
        this.DrawerItem('Browser', 'browser')
        this.DrawerItem('Screens', 'screens')
        this.DrawerItem('Settings', 'settings')
        this.DrawerItem('About', 'about')
        this.DrawerItem('More', 'more')
        Divider()
          .margin({ top: 6, bottom: 6 })
        Text('TOOLS')
          .fontSize(10)
          .fontColor('#999999')
          .padding({ left: 12, bottom: 2 })
        this.DrawerItem('Apps', 'apps')
        this.DrawerItem('Runs and batches', 'runs')
        this.DrawerItem('Models', 'models')
        this.DrawerItem('Usage', 'usage')
        this.DrawerItem('Phone setup', 'phone')
        this.DrawerItem('Self-check', 'selfcheck')
        this.DrawerItem('Welcome', 'welcome')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  PageHost() {
    if (this.activePage === 'plans') {
      PlansPage()
    } else if (this.activePage === 'memory') {
      MemoryPage()
    } else if (this.activePage === 'browser') {
      BrowserPage()
    } else if (this.activePage === 'screens') {
      ScreensPage()
    } else if (this.activePage === 'settings') {
      SettingsPage()
    } else if (this.activePage === 'about') {
      AboutPage()
    } else if (this.activePage === 'more') {
      this.MoreToolsPage()
    } else if (this.activePage === 'source') {
      this.MoreContainer('source')
    } else if (this.activePage === 'mcpservers') {
      this.MoreContainer('mcpservers')
    } else if (this.activePage === 'files') {
      this.MoreContainer('files')
    } else if (this.activePage === 'license') {
      this.MoreContainer('license')
    } else if (this.activePage === 'apps') {
      this.MoreContainer('apps')
    } else if (this.activePage === 'runs') {
      RunsPage()
    } else if (this.activePage === 'models') {
      this.MoreContainer('models')
    } else if (this.activePage === 'usage') {
      this.MoreContainer('usage')
    } else if (this.activePage === 'phone') {
      this.MoreContainer('phone')
    } else if (this.activePage === 'selfcheck') {
      SelfCheckPage()
    } else if (this.activePage === 'welcome') {
      WelcomePage({ onOpenSettings: () => { this.activePage = 'settings'; this.menuOpen = false; }, onOpenChat: () => { this.activePage = 'chat'; this.menuOpen = false; } })
    } else {
      ChatPage()
    }
  }

  @Builder
  MoreContainer(key: string) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Button('Back')
          .fontSize(12)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
                    this.activePage = 'more';
          })
        Text(this.containerTitle(key))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      Column() {
        if (key === 'apps') {
          AppsPage({
            onOpenSite: (url: string) => {
              AgentService.get().browser.requestUrl(url);
              this.activePage = 'browser';
            }
          })
        } else if (key === 'runs') {
          RunsPage()
        } else if (key === 'models') {
          ModelsPage({ onOpenSettings: () => { this.activePage = 'settings'; this.menuOpen = false; } })
        } else if (key === 'usage') {
          UsagePage()
        } else if (key === 'phone') {
          PhonePage({ onOpenSettings: () => { this.activePage = 'settings'; this.menuOpen = false; } })
        } else if (key === 'selfcheck') {
          SelfCheckPage()
        } else if (key === 'welcome') {
          WelcomePage({ onOpenSettings: () => { this.activePage = 'settings'; this.menuOpen = false; }, onOpenChat: () => { this.activePage = 'chat'; this.menuOpen = false; } })
        } else if (key === 'about') {
          AboutPage()
        } else if (key === 'screens') {
          ScreensPage()
        } else if (key === 'source') {
          SourcePage()
        } else if (key === 'mcpservers') {
          McpServersPage()
        } else if (key === 'files') {
          FilesPage()
        } else if (key === 'license') {
          LicensePage()
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  private containerTitle(key: string): string {
    if (key === 'apps') {
      return 'Apps';
    }
    if (key === 'runs') {
      return 'Runs and batches';
    }
    if (key === 'models') {
      return 'Models';
    }
    if (key === 'usage') {
      return 'Usage';
    }
    if (key === 'phone') {
      return 'Phone setup';
    }
    if (key === 'selfcheck') {
      return 'Self-check';
    }
    if (key === 'welcome') {
      return 'Welcome';
    }
    if (key === 'screens') {
      return 'Screens';
    }
    if (key === 'source') {
      return 'Source';
    }
    if (key === 'mcpservers') {
      return 'MCP servers';
    }
    if (key === 'files') {
      return 'Files';
    }
    if (key === 'license') {
      return 'License';
    }
    return 'About';
  }


  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      this.Drawer()
      Column() {
        Row({ space: 10 }) {
          Text('☰')
            .fontSize(24)
            .fontColor('#333333')
            .padding(8)
            .onClick(() => {
              this.refreshChats();
              this.menuOpen = true;
            })
          Text(this.pageTitle())
            .fontSize(14)
            .fontColor('#666666')
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .padding({ left: 8, right: 12 })
        Column() {
          this.PageHost()
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .showSideBar(this.menuOpen)
    .showControlButton(false)
    .sideBarWidth(280)
    .minSideBarWidth(240)
    .maxSideBarWidth(320)
    .onChange((value: boolean) => {
      this.menuOpen = value;
    })
    .width('100%')
    .height('100%')
  }
}


