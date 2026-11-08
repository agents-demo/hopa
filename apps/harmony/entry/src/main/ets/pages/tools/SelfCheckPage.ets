import { AgentService } from '../../services/AgentService';

/** Checks the model, the bridge and the device state before a task. */
@Component
export struct SelfCheckPage {
  @State model: string = 'not checked';
  @State bridge: string = 'not checked';
  @State accessibility: string = 'not checked';

  private color(value: string): ResourceColor {
    if (value === 'ok' || value === 'on') {
      return $r('app.color.success');
    }
    if (value === 'not checked') {
      return $r('app.color.text_hint');
    }
    return $r('app.color.danger');
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
        .fontColor($r('app.color.text_secondary'))
      Row() {
        Text('Model').fontSize(14).layoutWeight(1)
        Text(this.model).fontSize(13).fontColor(this.color(this.model))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Row() {
        Text('PC bridge').fontSize(14).layoutWeight(1)
        Text(this.bridge).fontSize(13).fontColor(this.color(this.bridge))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Row() {
        Text('Accessibility').fontSize(14).layoutWeight(1)
        Text(this.accessibility).fontSize(13).fontColor(this.color(this.accessibility))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Row() {
        Text('Network for web tasks').fontSize(14).layoutWeight(1)
        Text(AgentService.get().isNetworkEnabled() ? 'on' : 'off')
          .fontSize(13)
          .fontColor(AgentService.get().isNetworkEnabled() ? $r('app.color.success') : $r('app.color.danger'))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Row() {
        Text('Facts and skills').fontSize(14).layoutWeight(1)
        Text(`${AgentService.get().memory.all().length} / ${AgentService.get().skills.all().length}`)
          .fontSize(13)
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      Button('Run check')
        .fontSize(12)
        .onClick(() => {
          this.run();
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
