import { AgentService } from '../services/AgentService';
import { ActivityPage } from './activity/ActivityPage';
import { CapabilitiesPage } from './capabilities/CapabilitiesPage';
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
import { EasyHome } from './home/EasyHome';
import { PowerHome } from './home/PowerHome';
import { SocialHome } from './home/SocialHome';
import { KidHome } from './home/KidHome';
import { EasyHistory } from './home/EasyHistory';

/** Maps the active page key to one page; the shell owns navigation only. */
@Component
export struct PageRouter {
  @Prop activePage: string = 'chat';
  @StorageLink('hopa.profile') profileName: string = 'everyday';
  onNavigate: (key: string) => void = () => {};
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenRuns: () => void = () => {};

  build() {
    if (this.activePage === 'home') {
      if (this.profileName === 'easy') {
        EasyHome()
      } else if (this.profileName === 'power') {
        PowerHome({
          onOpenChat: (goal: string, voice: boolean) => { this.onOpenChat(goal, voice); },
          onOpenRuns: () => { this.onOpenRuns(); }
        })
      } else if (this.profileName === 'social') {
        SocialHome({
          onOpenChat: (goal: string, voice: boolean) => { this.onOpenChat(goal, voice); },
          onOpenRuns: () => { this.onOpenRuns(); }
        })
      } else if (this.profileName === 'kid') {
        KidHome({
          onOpenChat: (goal: string, voice: boolean) => { this.onOpenChat(goal, voice); },
          onOpenSettings: () => { this.onNavigate('capabilities'); }
        })
      } else {
        ChatPage()
      }
    } else if (this.activePage === 'easyhistory') {
      EasyHistory()
    } else if (this.activePage === 'activity') {
      ActivityPage({ onNavigate: (key: string) => { this.onNavigate(key); } })
    } else if (this.activePage === 'capabilities') {
      CapabilitiesPage({ onNavigate: (key: string) => { this.onNavigate(key); } })
    } else if (this.activePage === 'plans') {
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
