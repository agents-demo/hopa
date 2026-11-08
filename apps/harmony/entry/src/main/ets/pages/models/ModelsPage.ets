import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** The configured model and the provider story. */
@Component
export struct ModelsPage {
  onOpenSettings: () => void = () => {};

  @State provider: string = 'openai';
  @State endpoint: string = '';
  @State model: string = '';
  @State label: string = '';

  aboutToAppear(): void {
    this.label = AgentService.get().getModelLabel();
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

  build() {
    Column({ space: 12 }) {
      Text('Current model')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text(this.label.length > 0 ? this.label : 'not configured')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text(`Provider: ${this.provider}`)
        .fontSize(12)
      Text(`Endpoint: ${this.endpoint}`)
        .fontSize(12)
        .maxLines(1)
      Text(`Model: ${this.model}`)
        .fontSize(12)
      Text('Presets')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('OpenAI-compatible (OpenAI, DeepSeek, local), Anthropic and Gemini use the same fields. Speech models are not available in this SDK.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Button('Open Settings')
        .fontSize(12)
        .onClick(() => {
          this.onOpenSettings();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
