import { AgentService } from '../services/AgentService';
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
import { MoreToolsPage } from './tools/MoreToolsPage';
import { ScreensPage } from './tools/ScreensPage';
import { SelfCheckPage } from './tools/SelfCheckPage';
import { FilesPage } from './tools/FilesPage';
import { LicensePage } from './tools/LicensePage';
import { AboutPage } from './tools/AboutPage';
import { WelcomePage } from './tools/WelcomePage';

/** Maps the active page key to one page; the shell owns navigation only. */
@Component
export struct PageRouter {
  @Prop activePage: string = 'chat';
  onNavigate: (key: string) => void = () => {};

  build() {
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
      MoreToolsPage({ onNavigate: (key: string) => { this.onNavigate(key); } })
    } else if (this.activePage === 'source') {
      SourcePage()
    } else if (this.activePage === 'mcpservers') {
      McpServersPage()
    } else if (this.activePage === 'files') {
      FilesPage()
    } else if (this.activePage === 'license') {
      LicensePage()
    } else if (this.activePage === 'apps') {
      AppsPage({
        onOpenSite: (url: string) => {
          AgentService.get().browser.requestUrl(url);
          this.onNavigate('browser');
        }
      })
    } else if (this.activePage === 'runs') {
      RunsPage()
    } else if (this.activePage === 'models') {
      ModelsPage({ onOpenSettings: () => { this.onNavigate('settings'); } })
    } else if (this.activePage === 'usage') {
      UsagePage()
    } else if (this.activePage === 'phone') {
      PhonePage({ onOpenSettings: () => { this.onNavigate('settings'); } })
    } else if (this.activePage === 'selfcheck') {
      SelfCheckPage()
    } else if (this.activePage === 'welcome') {
      WelcomePage({
        onOpenSettings: () => { this.onNavigate('settings'); },
        onOpenChat: () => { this.onNavigate('chat'); }
      })
    } else {
      ChatPage()
    }
  }
}
