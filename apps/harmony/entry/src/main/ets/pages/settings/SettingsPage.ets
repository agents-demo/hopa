import { accessibility } from '@kit.AccessibilityKit';
import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';
import { AboutPage } from '../tools/AboutPage';
import { SelfCheckPage } from '../tools/SelfCheckPage';
import { AppAccessPage } from './AppAccessPage';
import { ComputerAccessPage } from './ComputerAccessPage';
import { DeveloperPage } from './DeveloperPage';

/** Model, bridge, safety switches and the advanced sub-pages. */
@Component
export struct SettingsPage {
  @State provider: string = 'openai';
  @State modelEndpoint: string = 'https://api.openai.com/v1';
  @State modelName: string = 'gpt-4o-mini';
  @State apiKey: string = '';
  @State modelLabel: string = '';
  @State networkEnabled: boolean = false;
  @State autonomous: boolean = false;
  @State bridgeUrl: string = '';
  @State bridgeToken: string = '';
  @State bridgeStatus: string = 'not connected';
  @State a11yAvailable: boolean = false;
  @State a11yInstalled: string = 'checking...';
  @State accessibilityEnabled: boolean = false;
  @State subPage: string = '';
  @State status: string = '';

  aboutToAppear(): void {
    this.a11yAvailable = AgentService.get().isAccessibilityAvailable();
    this.modelLabel = AgentService.get().getModelLabel();
    this.load();
    this.loadA11yList();
  }

  private async load(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.provider = stored.provider;
      this.modelEndpoint = stored.endpoint;
      this.modelName = stored.model;
      this.networkEnabled = stored.network;
      this.autonomous = stored.autonomous;
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (this.bridgeUrl.length > 0 && this.bridgeToken.length > 0) {
        this.bridgeStatus = 'connected (saved)';
      }
    } catch (error) {
      // First run: keep the defaults.
    }
  }

  private async loadA11yList(): Promise<void> {
    try {
      const list = await accessibility.getAccessibilityExtensionList('all', 'install');
      const names: string[] = [];
      for (const item of list) {
        names.push(`${item.bundleName}/${item.name}`);
      }
      this.a11yInstalled = names.length > 0 ? names.join(', ') : 'none';
    } catch (error) {
      this.a11yInstalled = `error: ${error}`;
    }
  }

  private persist(): void {
    const stored = new StoredSettings();
    stored.provider = this.provider;
    stored.endpoint = this.modelEndpoint;
    stored.model = this.modelName;
    stored.network = this.networkEnabled;
    stored.autonomous = this.autonomous;
    stored.bridgeUrl = this.bridgeUrl;
    stored.bridgeToken = this.bridgeToken;
    SettingsStore.save(getContext(this) as Context, stored).catch(() => {
      // Persistence is best effort; the in-memory settings still work.
    });
  }

  private saveModel(): void {
    const service = AgentService.get();
    service.configureModel(
      this.provider,
      this.modelEndpoint.trim(),
      this.apiKey,
      this.modelName.trim(),
      6
    );
    this.modelLabel = service.getModelLabel();
    this.persist();
    this.status = `${this.provider} model set to ${this.modelLabel}. The key stays in memory.`;
  }

  private providerIndex(): number {
    if (this.provider === 'anthropic') {
      return 1;
    }
    if (this.provider === 'gemini') {
      return 2;
    }
    if (this.provider === 'deepseek') {
      return 3;
    }
    return 0;
  }

  private async connectBridge(): Promise<void> {
    AgentService.get().configureBridge(this.bridgeUrl, this.bridgeToken);
    if (!AgentService.get().isBridgeConfigured()) {
      this.bridgeStatus = 'enter URL and token';
      return;
    }
    this.bridgeStatus = 'checking...';
    const ok: boolean = await AgentService.get().testBridge();
    this.bridgeStatus = ok ? 'connected' : `unreachable: ${AgentService.get().bridgeFailure()}`;
    if (ok) {
      this.persist();
    }
  }

  private subTitle(): string {
    if (this.subPage === 'appaccess') {
      return 'App access';
    }
    if (this.subPage === 'computer') {
      return 'Computer access';
    }
    if (this.subPage === 'developer') {
      return 'Developer';
    }
    if (this.subPage === 'selfcheck') {
      return 'Self-check';
    }
    return 'About';
  }

  @Builder
  Row(title: string, subtitle: string, key: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(14)
        Text(subtitle).fontSize(10).fontColor('#999999')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>').fontSize(14).fontColor('#999999')
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F7F8FA')
    .borderRadius(8)
    .onClick(() => {
      this.subPage = key;
    })
  }

  @Builder
  SubPage() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Button('Back')
          .fontSize(12)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            this.subPage = '';
          })
        Text(this.subTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      Column() {
        if (this.subPage === 'appaccess') {
          AppAccessPage()
        } else if (this.subPage === 'computer') {
          ComputerAccessPage({ onOpenSettings: () => { this.subPage = ''; } })
        } else if (this.subPage === 'developer') {
          DeveloperPage()
        } else if (this.subPage === 'selfcheck') {
          SelfCheckPage()
        } else {
          AboutPage()
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

  build() {
    if (this.subPage.length > 0) {
      this.SubPage()
    } else {
      Scroll() {
        Column({ space: 16 }) {
          Text('Settings')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Row() {
            Text('Allow network for web tasks').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.networkEnabled })
              .onChange((on: boolean) => {
                this.networkEnabled = on;
                AgentService.get().setNetworkEnabled(on);
                this.persist();
              })
          }
          .width('100%')
          Row() {
            Text(this.a11yAvailable
              ? 'Accessibility service (available)'
              : 'Accessibility service (requires ACL)')
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.accessibilityEnabled })
              .enabled(this.a11yAvailable)
              .onChange((on: boolean) => {
                this.accessibilityEnabled = on;
              })
          }
          .width('100%')
          Row() {
            Text('Autonomous mode (never skips payment)').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.autonomous })
              .onChange((on: boolean) => {
                this.autonomous = on;
                AgentService.get().setAutonomous(on);
                this.persist();
              })
          }
          .width('100%')
          Text('PC bridge (fallback control)')
            .fontSize(14)
            .fontColor('#666666')
          TextInput({ text: this.bridgeUrl, placeholder: 'http://192.168.1.10:8765' })
            .onChange((value: string) => {
              this.bridgeUrl = value;
            })
          TextInput({ text: this.bridgeToken, placeholder: 'bridge token' })
            .type(InputType.Password)
            .onChange((value: string) => {
              this.bridgeToken = value;
            })
          Row({ space: 8 }) {
            Button('Connect')
              .fontSize(12)
              .onClick(() => {
                this.connectBridge();
              })
            Text(this.bridgeStatus)
              .fontSize(12)
              .fontColor('#666666')
          }
          .width('100%')
          Text('Run "pc-agent bridge" on the PC. Used only when accessibility is unavailable.')
            .fontSize(11)
            .fontColor('#999999')
          Text('Model provider')
            .fontSize(14)
            .fontColor('#666666')
          Select([
            { value: 'openai' },
            { value: 'anthropic' },
            { value: 'gemini' },
            { value: 'deepseek' }
          ])
            .selected(this.providerIndex())
            .value(this.provider)
            .onSelect((index: number, value: string) => {
              this.provider = value;
              if (value === 'anthropic') {
                if (this.modelEndpoint === 'https://api.openai.com/v1') {
                  this.modelEndpoint = 'https://api.anthropic.com';
                }
                if (this.modelName === 'gpt-4o-mini') {
                  this.modelName = 'claude-3-5-sonnet-latest';
                }
              } else if (value === 'gemini') {
                if (this.modelEndpoint === 'https://api.openai.com/v1' ||
                  this.modelEndpoint === 'https://api.anthropic.com') {
                  this.modelEndpoint = 'https://generativelanguage.googleapis.com';
                }
                if (this.modelName === 'gpt-4o-mini' || this.modelName === 'claude-3-5-sonnet-latest') {
                  this.modelName = 'gemini-2.0-flash';
                }
              } else if (value === 'deepseek') {
                this.modelEndpoint = 'https://api.deepseek.com/v1';
                if (this.modelName === 'gpt-4o-mini' ||
                  this.modelName === 'claude-3-5-sonnet-latest' ||
                  this.modelName === 'gemini-2.0-flash') {
                  this.modelName = 'deepseek-v4-flash';
                }
              } else {
                if (this.modelEndpoint === 'https://api.anthropic.com' ||
                  this.modelEndpoint === 'https://generativelanguage.googleapis.com') {
                  this.modelEndpoint = 'https://api.openai.com/v1';
                }
                if (this.modelName === 'claude-3-5-sonnet-latest' || this.modelName === 'gemini-2.0-flash') {
                  this.modelName = 'gpt-4o-mini';
                }
              }
              this.persist();
            })
          Text('Model endpoint')
            .fontSize(14)
            .fontColor('#666666')
          TextInput({ text: this.modelEndpoint })
            .onChange((value: string) => {
              this.modelEndpoint = value;
            })
          Text('Model name')
            .fontSize(14)
            .fontColor('#666666')
          TextInput({ text: this.modelName })
            .onChange((value: string) => {
              this.modelName = value;
            })
          Text('API key (kept in memory only, never saved)')
            .fontSize(14)
            .fontColor('#666666')
          TextInput({ text: this.apiKey, placeholder: 'sk-...' })
            .type(InputType.Password)
            .onChange((value: string) => {
              this.apiKey = value;
            })
          Button(this.modelLabel.length > 0 ? `Save (current: ${this.modelLabel})` : 'Save model settings')
            .onClick(() => {
              this.saveModel();
            })
          if (this.status.length > 0) {
            Text(this.status)
              .fontSize(11)
              .fontColor('#666666')
          }
          Text('Payment: always requires your confirmation. This cannot be changed.')
            .fontSize(13)
            .fontColor('#B42318')
          Text(`Installed accessibility services: ${this.a11yInstalled}`)
            .fontSize(11)
            .fontColor('#666666')
          Text('Sandbox: not bundled. Pyodide/QuickJS are optional WASM pages; there is no Linux sandbox.')
            .fontSize(12)
            .fontColor('#666666')
          Text('Retention: last 100 runs and 50 remembered facts. Skills stay until you delete them.')
            .fontSize(12)
            .fontColor('#666666')
          Text('Advanced')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
          this.Row('App access', 'Which bundles may be launched', 'appaccess')
          this.Row('Computer access', 'PC bridge and MCP commands', 'computer')
          this.Row('Self-check', 'Verify the setup', 'selfcheck')
          this.Row('Developer', 'Build and runtime details', 'developer')
          this.Row('About', 'Version, credits and licenses', 'about')
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
    }
  }
}
