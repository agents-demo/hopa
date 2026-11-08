import { AgentService } from '../../services/AgentService';
import { APP_CATALOG } from '../../services/AppCatalog';

/** Capabilities: what HOPA can use on this phone and what powers it. */
@Component
export struct CapabilitiesPage {
  onNavigate: (key: string) => void = () => {};

  private model(): string {
    const label: string = AgentService.get().getModelLabel();
    return label.length > 0 ? label : 'No model';
  }

  private control(): string {
    const onDevice: boolean = AgentService.get().isAccessibilityAvailable();
    const bridge: boolean = AgentService.get().isBridgeConfigured();
    if (onDevice && bridge) {
      return 'On-device + PC bridge';
    }
    if (onDevice) {
      return 'On-device';
    }
    if (bridge) {
      return 'PC bridge';
    }
    return 'Not set up';
  }

  private ready(): boolean {
    return AgentService.get().isAccessibilityAvailable() ||
      AgentService.get().isBridgeConfigured();
  }

  private memoryCount(): number {
    return AgentService.get().memory.all().length;
  }

  @Builder
  Tile(title: string, subtitle: string, key: string) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
      Text(subtitle)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(78)
    .padding(12)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.onNavigate(key);
    })
  }

  @Builder
  Section(label: string) {
    Text(label)
      .fontSize(10)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.6)
      .width('100%')
      .padding({ top: 6 })
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Column({ space: 6 }) {
          Text(this.model())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Row({ space: 6 }) {
            Column()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.ready()
                ? $r('app.color.success')
                : $r('app.color.warning'))
            Text(`Phone control · ${this.control()}`)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.onNavigate('phone');
        })
        this.Section('WHAT HOPA CAN USE')
        Row({ space: 8 }) {
          this.Tile('Apps', `${APP_CATALOG.length} apps to open`, 'apps')
          this.Tile('Browser', 'Read, click and type', 'browser')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.Tile('Memory', `${this.memoryCount()} facts`, 'memory')
          this.Tile('Screens', 'Live phone screen', 'screens')
        }
        .width('100%')
        this.Section('POWER')
        Row({ space: 8 }) {
          this.Tile('Models', 'Provider, endpoint and key', 'models')
          this.Tile('Usage', 'Tokens and time spent', 'usage')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.Tile('Phone access', 'Accessibility and bridge', 'phone')
          this.Tile('MCP servers', 'Phone and PC tools', 'mcpservers')
        }
        .width('100%')
        this.Section('APP')
        Row({ space: 8 }) {
          this.Tile('Files', 'Exported data', 'files')
          this.Tile('Source', 'Model and backend', 'source')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.Tile('Welcome', 'The first-run tour', 'welcome')
          this.Tile('About', 'Version and links', 'about')
        }
        .width('100%')
        Row({ space: 8 }) {
          this.Tile('License', 'Apache-2.0 and notices', 'license')
          this.Tile('Self-check', 'What works here', 'selfcheck')
        }
        .width('100%')
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
