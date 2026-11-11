import { Context } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';
import { KeyStore } from '../../services/KeyStore';

/** The model card on the Settings page. Owns the model fields and the key. */
@Component
export struct ModelSettingsCard {
  @State provider: string = 'openai';
  @State endpoint: string = 'https://api.openai.com/v1';
  @State modelName: string = 'gpt-4o-mini';
  @State apiKey: string = '';
  @State keyReady: boolean = false;
  @State modelLabel: string = '';
  @State status: string = '';

  aboutToAppear(): void {
    this.modelLabel = AgentService.get().getModelLabel();
    this.keyReady = AgentService.get().hasModelKey();
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
    const key: string = this.apiKey.trim();
    if (key.length === 0 && !service.hasModelKey()) {
      this.status = 'Enter an API key first.';
      return;
    }
    if (key.length === 0) {
      service.reconfigureModel(this.provider, this.endpoint.trim(), this.modelName.trim());
      this.modelLabel = service.getModelLabel();
      this.persist();
      this.status = 'Model saved. The loaded key is still active.';
      return;
    }
    service.configureModel(
      this.provider,
      this.endpoint.trim(),
      key,
      this.modelName.trim(),
      8
    );
    this.keyReady = true;
    this.apiKey = '';
    this.modelLabel = service.getModelLabel();
    this.persist();
    this.status = 'Saving the key on this phone...';
    KeyStore.save(key).then((saved: boolean) => {
      this.status = saved
        ? 'Model saved. The key is stored securely on this phone.'
        : 'Model saved for this session (secure storage unavailable).';
    }).catch(() => {
      this.status = 'Model saved for this session.';
    });
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
      Text(this.keyReady
        ? 'API key (loaded; leave blank to keep it)'
        : 'API key')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      TextInput({
        text: this.apiKey,
        placeholder: this.keyReady ? 'Key is loaded - leave blank to keep it' : 'sk-...'
      })
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
