import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';

/** Build and runtime details, plus the history reset. */
@Component
export struct DeveloperPage {
  @State status: string = '';

  private clearRuns(): void {
    AgentService.get().runs.clear();
    AgentService.get().saveRuns(getContext(this) as Context).catch(() => {
      // Persistence is best effort.
    });
    this.status = 'Cleared the run history';
  }

  @Builder
  Line(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
        .width(120)
      Text(value)
        .fontSize(12)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius(6)
  }

  build() {
    Column({ space: 10 }) {
      this.Line('App', 'HOPA 0.1.0 (com.hopa.agent)')
      this.Line('Runtime', 'ArkTS on HarmonyOS, API 24')
      this.Line('Model', AgentService.get().getModelLabel().length > 0
        ? AgentService.get().getModelLabel()
        : 'not configured')
      this.Line('Accessibility', AgentService.get().isAccessibilityAvailable() ? 'available' : 'unavailable')
      this.Line('PC bridge', AgentService.get().isBridgeConfigured() ? 'configured' : 'not configured')
      this.Line('Runs stored', `${AgentService.get().runs.all().length}`)
      this.Line('Plans stored', `${AgentService.get().scheduleService.book.all().length}`)
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      Button('Clear run history')
        .fontSize(12)
        .backgroundColor($r('app.color.divider'))
        .fontColor($r('app.color.danger'))
        .onClick(() => {
          this.clearRuns();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
