import { AgentService } from '../../services/AgentService';

/** Checks the model, the bridge and the device state before a task. */
@Component
export struct SelfCheckPage {
  @State model: string = 'not checked';
  @State bridge: string = 'not checked';
  @State accessibility: string = 'not checked';

  private color(value: string): string {
    if (value === 'ok' || value === 'on') {
      return '#0A7F3F';
    }
    if (value === 'not checked') {
      return '#999999';
    }
    return '#B42318';
  }

  private async run(): Promise<void> {
    this.model = AgentService.get().hasModel() ? 'ok' : 'missing';
    if (AgentService.get().isBridgeConfigured()) {
      this.bridge = await AgentService.get().testBridge() ? 'ok' : 'unreachable';
    } else {
      this.bridge = 'not configured';
    }
    this.accessibility = AgentService.get().isAccessibilityAvailable() ? 'ok' : 'unavailable';
  }

  build() {
    Column({ space: 10 }) {
      Text('Run the checks before a task.')
        .fontSize(12)
        .fontColor('#666666')
      Row() {
        Text('Model').fontSize(14).layoutWeight(1)
        Text(this.model).fontSize(13).fontColor(this.color(this.model))
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(8)
      Row() {
        Text('PC bridge').fontSize(14).layoutWeight(1)
        Text(this.bridge).fontSize(13).fontColor(this.color(this.bridge))
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(8)
      Row() {
        Text('Accessibility').fontSize(14).layoutWeight(1)
        Text(this.accessibility).fontSize(13).fontColor(this.color(this.accessibility))
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(8)
      Row() {
        Text('Network for web tasks').fontSize(14).layoutWeight(1)
        Text(AgentService.get().isNetworkEnabled() ? 'on' : 'off')
          .fontSize(13)
          .fontColor(AgentService.get().isNetworkEnabled() ? '#0A7F3F' : '#B42318')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(8)
      Row() {
        Text('Facts and skills').fontSize(14).layoutWeight(1)
        Text(`${AgentService.get().memory.all().length} / ${AgentService.get().skills.all().length}`)
          .fontSize(13)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#F7F8FA')
      .borderRadius(8)
      Button('Run check')
        .fontSize(12)
        .onClick(() => {
          this.run();
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
