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
  @State keyReady: boolean = false;

  aboutToAppear(): void {
    this.label = AgentService.get().getModelLabel();
    this.keyReady = AgentService.get().hasModelKey();
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
    Row({ space: 12 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width(78)
      Text(value.length > 0 ? value : 'not set')
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 4 }) {
          Text('CURRENT MODEL')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.6)
          Text(this.label.length > 0 ? this.label : 'Not configured')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.keyReady ? 'Ready for every new task.' : 'Add an API key in Settings to use this model.')
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)
        .alignItems(HorizontalAlign.Start)
        Column({ space: 0 }) {
          this.Line('Provider', this.provider)
          Divider().color($r('app.color.divider'))
          this.Line('Endpoint', this.endpoint)
          Divider().color($r('app.color.divider'))
          this.Line('Model', this.model)
          Divider().color($r('app.color.divider'))
          this.Line('Key', this.keyReady ? 'Loaded (hidden)' : 'Missing')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 2, bottom: 2 })
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)
        Column({ space: 6 }) {
          Text('Presets')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
          Text('OpenAI-compatible (OpenAI, DeepSeek, local), Anthropic and Gemini use the same fields. Speech models are not available in this SDK.')
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
            .lineHeight(17)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 4 })
        Button('Open Settings')
          .width('100%')
          .height(44)
          .fontSize(14)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.onOpenSettings();
          })
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
