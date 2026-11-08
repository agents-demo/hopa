import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** Where the last answer looked: model, backend and usage. */
@Component
export struct SourcePage {
  @State provider: string = 'openai';
  @State endpoint: string = '';
  @State model: string = '';

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.provider = stored.provider;
      this.endpoint = stored.endpoint;
      this.model = stored.model;
    } catch (error) {
      // First run: keep the defaults.
    }
  }

  @Builder
  Line(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
        .width(120)
      Text(value)
        .fontSize(13)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.surface_alt'))
    .borderRadius(6)
  }

  build() {
    Column({ space: 10 }) {
      Text('Where the last answer looked')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
      this.Line('Provider', this.provider)
      this.Line('Endpoint', this.endpoint)
      this.Line('Model', this.model)
      this.Line('Control backend', AgentService.get().isBridgeConfigured()
        ? 'PC bridge: live screen and taps'
        : (AgentService.get().isAccessibilityAvailable() ? 'on-device accessibility' : 'built-in browser text only'))
      this.Line('Last run', `${AgentService.get().getLastTokens()} tokens, ${(AgentService.get().getLastDurationMs() / 1000).toFixed(1)} s`)
      Text('Screen text and page URLs are not stored per run yet, so this page reports the configured source instead of a citation list.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
