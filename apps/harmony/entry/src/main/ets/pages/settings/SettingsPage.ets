import { accessibility } from '@kit.AccessibilityKit';
import { Context, common } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { Appearance } from '../../services/Appearance';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';
import { AboutPage } from '../tools/AboutPage';
import { SelfCheckPage } from '../tools/SelfCheckPage';
import { ScreensPage } from '../tools/ScreensPage';
import { AppAccessPage } from './AppAccessPage';
import { ComputerAccessPage } from './ComputerAccessPage';
import { DeveloperPage } from './DeveloperPage';
import { ModelSettingsCard } from './ModelSettingsCard';

/** Model, bridge, safety switches and the advanced sub-pages. */
@Component
export struct SettingsPage {
  @State networkEnabled: boolean = false;
  @State autonomous: boolean = false;
  @State bridgeUrl: string = '';
  @State bridgeToken: string = '';
  @State bridgeStatus: string = 'not connected';
  @State appearance: string = 'system';
  @State a11yAvailable: boolean = false;
  @State a11yInstalled: string = 'checking...';
  @State subPage: string = '';

  aboutToAppear(): void {
    this.a11yAvailable = AgentService.get().isAccessibilityAvailable();
    this.load();
    this.loadA11yList();
  }

  private async load(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.networkEnabled = stored.network;
      this.autonomous = stored.autonomous;
      this.appearance = stored.appearance;
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (this.bridgeUrl.length > 0 && this.bridgeToken.length > 0) {
        await this.refreshBridge();
      }
    } catch (error) {
      // First run: keep the defaults.
    }
  }

  private async refreshBridge(): Promise<void> {
    if (!AgentService.get().isBridgeConfigured()) {
      this.bridgeStatus = 'not connected';
      return;
    }
    this.bridgeStatus = 'checking...';
    const ok: boolean = await AgentService.get().testBridge();
    this.bridgeStatus = ok ? 'connected' : `unreachable: ${AgentService.get().bridgeFailure()}`;
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
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.network = this.networkEnabled;
      stored.autonomous = this.autonomous;
      stored.appearance = this.appearance;
      stored.bridgeUrl = this.bridgeUrl;
      stored.bridgeToken = this.bridgeToken;
      return SettingsStore.save(context, stored);
    }).catch(() => {
      // Persistence is best effort; the in-memory settings still work.
    });
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
    if (this.subPage === 'screens') {
      return 'Live screen';
    }
    return 'About';
  }

  @Builder
  Row(title: string, subtitle: string, key: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title).fontSize(14)
        Text(subtitle).fontSize(10).fontColor($r('app.color.text_hint'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>').fontSize(14).fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.surface_alt'))
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
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
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
        } else if (this.subPage === 'screens') {
          ScreensPage()
        } else {
          AboutPage()
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Styles
  cardStyle() {
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(14)
  }

  @Builder
  Label(text: string) {
    Text(text)
      .fontSize(10)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.6)
      .width('100%')
      .padding({ top: 4 })
  }

  build() {
    if (this.subPage.length > 0) {
      this.SubPage()
    } else {
      Scroll() {
        Column({ space: 12 }) {
          this.Label('AGENT')
          Column({ space: 0 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('Allow network for web tasks')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text('Needed when HOPA opens a website.')
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.networkEnabled })
                .onChange((on: boolean) => {
                  this.networkEnabled = on;
                  AgentService.get().setNetworkEnabled(on);
                  this.persist();
                })
            }
            .width('100%')
            .padding({ top: 9, bottom: 9 })
            Divider().color($r('app.color.divider'))
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('Autonomous mode')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text('Never skips a payment.')
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.autonomous })
                .onChange((on: boolean) => {
                  this.autonomous = on;
                  AgentService.get().setAutonomous(on);
                  this.persist();
                })
            }
            .width('100%')
            .padding({ top: 9, bottom: 9 })
            Divider().color($r('app.color.divider'))
            Row({ space: 10 }) {
              Text('Appearance')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Select([
                { value: 'System' },
                { value: 'Light' },
                { value: 'Dark' }
              ])
                .selected(Appearance.indexOf(this.appearance))
                .value(Appearance.MODES[Appearance.indexOf(this.appearance)])
                .onSelect((index: number) => {
                  this.appearance = Appearance.modeAt(index);
                  Appearance.apply(
                    getContext(this) as common.UIAbilityContext,
                    this.appearance
                  );
                  this.persist();
                })
            }
            .width('100%')
            .padding({ top: 9, bottom: 9 })
          }
          .cardStyle()
          .alignItems(HorizontalAlign.Start)

          this.Label('PHONE ACCESS')
          Column({ space: 10 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(this.a11yAvailable
                  ? 'Accessibility service'
                  : 'Accessibility service (requires ACL)')
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text('Lets HOPA read and tap other apps on this phone.')
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text(this.a11yAvailable ? 'Available' : 'Needs ACL')
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.a11yAvailable
                  ? $r('app.color.success')
                  : $r('app.color.warning'))
            }
            .width('100%')
            Divider().color($r('app.color.divider'))
            Text('PC bridge (fallback control)')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            TextInput({ text: this.bridgeUrl, placeholder: 'http://192.168.1.10:8765' })
              .height(38)
              .fontSize(13)
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(9)
              .onChange((value: string) => {
                this.bridgeUrl = value;
              })
            TextInput({ text: this.bridgeToken, placeholder: 'bridge token' })
              .height(38)
              .fontSize(13)
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(9)
              .type(InputType.Password)
              .onChange((value: string) => {
                this.bridgeToken = value;
              })
            Row({ space: 8 }) {
              Button('Connect')
                .fontSize(12)
                .height(36)
                .backgroundColor($r('app.color.primary'))
                .fontColor($r('app.color.on_primary'))
                .onClick(() => {
                  this.connectBridge();
                })
              Text(this.bridgeStatus)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            Text('Run "pc-agent bridge" on the PC. Used only when accessibility is unavailable.')
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
          }
          .cardStyle()
          .alignItems(HorizontalAlign.Start)

          this.Label('MODEL')
          ModelSettingsCard()

          Column({ space: 4 }) {
            Text('Payment is always confirmed. This cannot be changed.')
              .fontSize(12)
              .fontColor($r('app.color.danger'))
            Text('There is no account and no hosted backend; your key goes to the model you choose.')
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
          }
          .cardStyle()
          .alignItems(HorizontalAlign.Start)

          this.Label('ADVANCED')
          Column({ space: 6 }) {
            this.Row('App access', 'Which bundles may be launched', 'appaccess')
            this.Row('Computer access', 'PC bridge and MCP commands', 'computer')
            this.Row('Self-check', 'Verify the setup', 'selfcheck')
            this.Row('Live screen', 'Debug mirror of this phone', 'screens')
            this.Row('Developer', 'Build and runtime details', 'developer')
            this.Row('About', 'Version, credits and licenses', 'about')
          }
          .width('100%')

          Text(`Installed accessibility services: ${this.a11yInstalled}`)
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
          Text('Sandbox: not bundled. Pyodide/QuickJS are optional WASM pages; there is no Linux sandbox.')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
          Text('Retention: last 100 runs and 50 remembered facts. Skills stay until you delete them.')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
  }
}
