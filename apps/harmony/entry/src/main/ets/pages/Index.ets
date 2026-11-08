import { Context, common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { ChatSession } from '@hopa/core';
import { AgentService } from '../services/AgentService';
import { SettingsStore, StoredSettings } from '../services/SettingsStore';
import { AppLauncher } from '../services/AppLauncher';
import { AppsPage } from './apps/AppsPage';
import { ChatPage } from './chat/ChatPage';
import { Drawer } from '../navigation/Drawer';
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
import { MoreToolsPage } from './tools/MoreToolsPage';
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
    service.setSiteOpener((url: string) => this.openSite(url));
    service.pageLinks.setOpener((url: string) => {
      service.browser.requestUrl(url);
      this.activePage = 'browser';
      this.menuOpen = false;
    });
    this.initialize();
  }

  /**
   * Switches to the Browser page for an agent navigation and waits until the
   * WebView is attached. This lets a short Chat prompt operate a site without
   * the user opening the Browser first.
   */
  private async openSite(url: string): Promise<boolean> {
    AgentService.get().browser.requestUrl(url);
    this.activePage = 'browser';
    this.menuOpen = false;
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

  private async initialize(): Promise<void> {
    await this.bootstrapSettings();
    await this.loadMemory();
    await this.loadSkills();
    await this.loadRuns();
    await AgentService.get().scheduleService.load(getContext(this) as Context);
    AgentService.get().scheduleService.start();
    AgentService.get().setUiLauncher(
      new AppLauncher(getContext(this) as common.UIAbilityContext)
    );
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

  /** Pages opened from the More page get a back arrow instead of the drawer. */
  private isMoreChild(): boolean {
    return this.activePage === 'apps' ||
      this.activePage === 'models' ||
      this.activePage === 'usage' ||
      this.activePage === 'phone' ||
      this.activePage === 'source' ||
      this.activePage === 'mcpservers' ||
      this.activePage === 'files' ||
      this.activePage === 'license';
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
      MoreToolsPage({ onNavigate: (key: string) => { this.activePage = key; } })
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
    Column() {
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
  }


  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Drawer({
        activePage: this.activePage,
        sessions: this.chatSessions,
        currentId: AgentService.get().conversations.currentId(),
        onNewChat: () => {
          AgentService.get().conversations.newChat();
          this.refreshChats();
          this.activePage = 'chat';
          this.menuOpen = false;
        },
        onSelect: (id: string) => {
          AgentService.get().conversations.select(id);
          this.refreshChats();
          this.activePage = 'chat';
          this.menuOpen = false;
        },
        onDelete: (id: string) => {
          AgentService.get().conversations.delete(id);
          this.refreshChats();
        },
        onNavigate: (key: string) => {
          this.activePage = key;
          this.menuOpen = false;
        }
      })
      Column() {
        Row({ space: 10 }) {
          if (this.isMoreChild()) {
            Text('‹')
              .fontSize(34)
              .fontColor('#333333')
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.activePage = 'more';
              })
          } else {
            Text('☰')
              .fontSize(24)
              .fontColor('#333333')
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.refreshChats();
                this.menuOpen = true;
              })
          }
          Text(this.pageTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0A1B3A')
            .layoutWeight(1)
        }
        .width('100%')
        .height(52)
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


