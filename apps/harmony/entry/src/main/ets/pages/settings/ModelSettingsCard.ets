import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** The model card on the Settings page. Owns the model fields and the key. */
@Component
export struct ModelSettingsCard {
  @State provider: string = 'openai';
  @State endpoint: string = 'https://api.openai.com/v1';
  @State modelName: string = 'gpt-4o-mini';
  @State apiKey: string = '';
  @State modelLabel: string = '';
  @State status: string = '';

  aboutToAppear(): void {
    this.modelLabel = AgentService.get().getModelLabel();
    this.load();
  }

  private async load(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.provider = stored.provider;
      this.endpoint = stored.endpoint;
      this.modelName = stored.model;
    } catch (error) {
      // First run: keep the defaults.
    }
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

  private async persist(): Promise<void> {
    try {
      const context = getContext(this) as Context;
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.provider = this.provider;
      stored.endpoint = this.endpoint;
      stored.model = this.modelName;
      await SettingsStore.save(context, stored);
    } catch (error) {
      // Persistence is best effort.
    }
  }

  private saveModel(): void {
    const service = AgentService.get();
    service.configureModel(
      this.provider,
      this.endpoint.trim(),
      this.apiKey,
      this.modelName.trim(),
      8
    );
    this.modelLabel = service.getModelLabel();
    this.persist();
    this.status = `${this.provider} model set to ${this.modelLabel}. The key stays in memory.`;
  }

  build() {
    Column({ space: 8 }) {
      Text('Provider')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
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
            if (this.endpoint === 'https://api.openai.com/v1') {
              this.endpoint = 'https://api.anthropic.com';
            }
            if (this.modelName === 'gpt-4o-mini') {
              this.modelName = 'claude-3-5-sonnet-latest';
            }
          } else if (value === 'gemini') {
            if (this.endpoint === 'https://api.openai.com/v1' ||
              this.endpoint === 'https://api.anthropic.com') {
              this.endpoint = 'https://generativelanguage.googleapis.com';
            }
            if (this.modelName === 'gpt-4o-mini' || this.modelName === 'claude-3-5-sonnet-latest') {
              this.modelName = 'gemini-2.0-flash';
            }
          } else if (value === 'deepseek') {
            this.endpoint = 'https://api.deepseek.com/v1';
            if (this.modelName === 'gpt-4o-mini' ||
              this.modelName === 'claude-3-5-sonnet-latest' ||
              this.modelName === 'gemini-2.0-flash') {
              this.modelName = 'deepseek-v4-flash';
            }
          } else {
            if (this.endpoint === 'https://api.anthropic.com' ||
              this.endpoint === 'https://generativelanguage.googleapis.com') {
              this.endpoint = 'https://api.openai.com/v1';
            }
            if (this.modelName === 'claude-3-5-sonnet-latest' || this.modelName === 'gemini-2.0-flash') {
              this.modelName = 'gpt-4o-mini';
            }
          }
          this.persist();
        })
      Text('Endpoint')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      TextInput({ text: this.endpoint })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.endpoint = value;
        })
      Text('Model name')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      TextInput({ text: this.modelName })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.modelName = value;
        })
      Text('API key (kept in memory only, never saved)')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      TextInput({ text: this.apiKey, placeholder: 'sk-...' })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .type(InputType.Password)
        .onChange((value: string) => {
          this.apiKey = value;
        })
      Button(this.modelLabel.length > 0
        ? `Save (current: ${this.modelLabel})`
        : 'Save model settings')
        .width('100%')
        .height(42)
        .fontSize(13)
        .backgroundColor($r('app.color.primary'))
        .fontColor($r('app.color.on_primary'))
        .onClick(() => {
          this.saveModel();
        })
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(14)
    .alignItems(HorizontalAlign.Start)
  }
}
