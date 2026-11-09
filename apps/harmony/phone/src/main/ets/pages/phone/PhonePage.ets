import { AgentService } from '../../services/AgentService';
import { HopaMark } from '../chat/HopaMark';

/** Phone access: the honest state of on-device control and the PC bridge. */
@Component
export struct PhonePage {
  onOpenSettings: () => void = () => {};
  @State bridgeState: string = 'not checked';
  @State checking: boolean = false;

  private async check(): Promise<void> {
    if (this.checking) {
      return;
    }
    if (!AgentService.get().isBridgeConfigured()) {
      this.bridgeState = 'not configured';
      return;
    }
    this.checking = true;
    this.bridgeState = 'checking...';
    try {
      const ok: boolean = await AgentService.get().testBridge();
      this.bridgeState = ok ? 'connected' : `unreachable (${AgentService.get().bridgeFailure()})`;
    } catch (error) {
      this.bridgeState = 'unreachable';
    } finally {
      this.checking = false;
    }
  }

  /** Never show a blank or stuck state, even before the first health check. */
  private statusText(): string {
    if (this.bridgeState === 'not checked') {
      return AgentService.get().isBridgeConfigured() ? 'configured' : 'not configured';
    }
    return this.bridgeState;
  }

  @Builder
  StateLine(title: string, value: string, note: string, good: boolean) {
    Column({ space: 3 }) {
      Row({ space: 8 }) {
        Text(title)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(value)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(good ? $r('app.color.success') : $r('app.color.warning'))
      }
      .width('100%')
      Text(note)
        .fontSize(11)
        .lineHeight(16)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          HopaMark({ state: 'idle', markSize: 48 })
          Column({ space: 2 }) {
            Text('Phone access')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('What HOPA can touch on this phone.')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        Column({ space: 0 }) {
          this.StateLine(
            'On-device control',
            AgentService.get().isAccessibilityAvailable() ? 'available' : 'not granted',
            AgentService.get().isAccessibilityAvailable()
              ? 'HOPA can read and tap other apps directly.'
              : 'This build needs Huawei\'s accessibility ACL. Until then, use the PC bridge.',
            AgentService.get().isAccessibilityAvailable()
          )
          Divider().color($r('app.color.divider'))
          Column({ space: 3 }) {
            Row({ space: 8 }) {
              Text('PC bridge')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
              Text(this.statusText())
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.statusText() === 'connected'
                  ? $r('app.color.success')
                  : $r('app.color.warning'))
            }
            .width('100%')
            Text('Runs pc-agent on your PC and sends taps over the USB tunnel or Wi-Fi.')
              .fontSize(11)
              .lineHeight(16)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 2, bottom: 2 })
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)

        if (this.statusText() !== 'connected') {
          Column({ space: 5 }) {
            Text('To connect')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text('1. On the PC: pc-agent bridge --host 127.0.0.1 --port 8766 --token <token>')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
            Text('2. Forward the port with hdc rport tcp:8766 tcp:8766.')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
            Text('3. Enter http://127.0.0.1:8766 and the token in Settings, then Connect.')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Row({ space: 8 }) {
          Button(this.checking ? 'Checking...' : 'Check again')
            .fontSize(12)
            .height(38)
            .enabled(!this.checking)
            .onClick(() => {
              this.check();
            })
          Button('Open Settings')
            .fontSize(12)
            .height(38)
            .backgroundColor($r('app.color.divider'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.onOpenSettings();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .onAppear(() => {
      this.check();
    })
  }
}
