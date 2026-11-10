import { common } from '@kit.AbilityKit';
import { LaptopChat, LaptopTurn } from '../services/LaptopChat';
import { LaptopKeyStore } from '../services/LaptopKeyStore';
import { LaptopSettings } from '../services/LaptopSettings';

/**
 * The HOPA workbench: one conversation, one input, everything else quiet.
 *
 * This shell runs the agent on the laptop itself. It never drives the phone,
 * and it never borrows the phone's key.
 */
@Entry
@Component
struct LaptopIndex {
  @State turns: LaptopTurn[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State keyPresent: boolean = false;
  @State modelName: string = 'deepseek-v4-flash';
  @State endpoint: string = 'https://api.deepseek.com/v1';
  @State settingsOpen: boolean = false;
  @State keyDraft: string = '';
  @State saved: string = '';
  private chat: LaptopChat = new LaptopChat();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    LaptopSettings.load(context).then((settings: LaptopSettings) => {
      this.endpoint = settings.endpoint;
      this.modelName = settings.model;
      LaptopKeyStore.load().then((key: string) => {
        this.keyPresent = key.length > 0;
        this.chat.configure(this.endpoint, this.modelName, key);
        this.applyInjected();
      }).catch(() => {
        // No key yet: the Model panel asks for one.
        this.applyInjected();
      });
    }).catch(() => {
      // Defaults are fine.
    });
  }

  /** A scripted first run can pass the key once; it lands in Asset Store and is forgotten. */
  private async applyInjected(): Promise<void> {
    const injectedKey: string = AppStorage.get<string>('hopa.laptop.key') ?? '';
    const injectedEndpoint: string = AppStorage.get<string>('hopa.laptop.endpoint') ?? '';
    const injectedModel: string = AppStorage.get<string>('hopa.laptop.model') ?? '';
    if (injectedEndpoint.length === 0 && injectedModel.length === 0 && injectedKey.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (injectedEndpoint.length > 0 || injectedModel.length > 0) {
      const settings = new LaptopSettings();
      settings.endpoint = injectedEndpoint.length > 0 ? injectedEndpoint : settings.endpoint;
      settings.model = injectedModel.length > 0 ? injectedModel : settings.model;
      await settings.save(context);
      this.endpoint = settings.endpoint;
      this.modelName = settings.model;
      AppStorage.setOrCreate<string>('hopa.laptop.endpoint', '');
      AppStorage.setOrCreate<string>('hopa.laptop.model', '');
    }
    if (injectedKey.length > 0) {
      const saved: boolean = await LaptopKeyStore.save(injectedKey);
      AppStorage.setOrCreate<string>('hopa.laptop.key', '');
      const key: string = await LaptopKeyStore.load();
      this.keyPresent = key.length > 0;
      this.saved = this.keyPresent ? 'Key saved.' : 'Key store unavailable.';
      this.chat.configure(this.endpoint, this.modelName, key);
    }
  }

  private async send(): Promise<void> {
    if (this.draft.trim().length === 0 || this.busy) {
      return;
    }
    if (!this.chat.isReady()) {
      this.settingsOpen = true;
      return;
    }
    const text: string = this.draft;
    this.draft = '';
    this.busy = true;
    await this.chat.send(text);
    this.turns = this.chat.turns.slice();
    this.error = this.chat.error;
    this.busy = false;
    this.scrollToEnd();
  }

  private scrollToEnd(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 40);
  }

  private async saveSettings(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const settings = new LaptopSettings();
    settings.endpoint = this.endpoint.trim().length > 0 ? this.endpoint.trim() : settings.endpoint;
    settings.model = this.modelName.trim().length > 0 ? this.modelName.trim() : settings.model;
    await settings.save(context);
    if (this.keyDraft.trim().length > 0) {
      const ok: boolean = await LaptopKeyStore.save(this.keyDraft);
      this.saved = ok ? 'Saved.' : 'That key looks too short.';
      this.keyDraft = '';
      const key: string = await LaptopKeyStore.load();
      this.keyPresent = key.length > 0;
      this.chat.configure(settings.endpoint, settings.model, key);
    } else {
      this.saved = 'Saved.';
      const key: string = await LaptopKeyStore.load();
      this.chat.configure(settings.endpoint, settings.model, key);
    }
    this.modelName = settings.model;
    this.endpoint = settings.endpoint;
  }

  @Builder
  Mark(size: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(size)
        .height(size * 1.12)
        .borderRadius(size * 0.28)
        .backgroundColor($r('app.color.primary'))
      Row()
        .width(size * 0.16)
        .height(size * 0.2)
        .borderRadius(size * 0.08)
        .backgroundColor('#FFFFFF')
        .position({ x: size * 0.24, y: size * 0.3 })
      Row()
        .width(size * 0.16)
        .height(size * 0.2)
        .borderRadius(size * 0.08)
        .backgroundColor('#FFFFFF')
        .position({ x: size * 0.6, y: size * 0.3 })
      Row()
        .width(size * 0.32)
        .height(size * 0.09)
        .borderRadius(size * 0.05)
        .backgroundColor('#FFFFFF')
        .position({ x: size * 0.34, y: size * 0.62 })
      Row()
        .width(size * 0.16)
        .height(size * 0.1)
        .borderRadius(size * 0.05)
        .backgroundColor($r('app.color.primary'))
        .position({ x: size * 0.78, y: size * 0.22 })
    }
    .width(size * 1.0)
    .height(size * 1.12)
  }

  @Builder
  Header() {
    Row({ space: 12 }) {
      this.Mark(26)
      Column({ space: 1 }) {
        Text('HOPA')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(-0.2)
        Text('Running on this laptop')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      if (this.turns.length > 0) {
        Text('New')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(16)
          .onClick(() => {
            this.chat.clear();
            this.turns = [];
            this.error = '';
          })
      }
      Text(this.keyPresent ? `Model · ${this.modelName}` : 'Add model key')
        .fontSize(12)
        .fontColor(this.keyPresent ? $r('app.color.text_secondary') : $r('app.color.primary'))
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(this.keyPresent
          ? $r('app.color.surface_alt')
          : $r('app.color.primary_soft'))
        .borderRadius(16)
        .onClick(() => {
          this.settingsOpen = !this.settingsOpen;
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 22, right: 22 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  SettingsPanel() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text('Model')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('Close')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.settingsOpen = false;
          })
      }
      .width('100%')
      Text('The key is stored in Asset Store on this laptop. It is not sent anywhere except to the endpoint below.')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      TextInput({ text: this.endpoint, placeholder: 'endpoint' })
        .height(38)
        .fontSize(12.5)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.endpoint = value;
        })
      TextInput({ text: this.modelName, placeholder: 'model name' })
        .height(38)
        .fontSize(12.5)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.modelName = value;
        })
      TextInput({ text: this.keyDraft, placeholder: this.keyPresent ? 'API key (loaded; leave blank to keep it)' : 'API key' })
        .height(38)
        .fontSize(12.5)
        .type(InputType.Password)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.keyDraft = value;
        })
      Row({ space: 10 }) {
        Button('Save')
          .height(36)
          .fontSize(12.5)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.saveSettings();
          })
        if (this.saved.length > 0) {
          Text(this.saved)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  Empty() {
    Column({ space: 12 }) {
      this.Mark(48)
      Text('HOPA')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .letterSpacing(-0.5)
      Text('Your agent. Ask for anything.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
      Text(this.keyPresent
        ? 'Running here, on this machine. It cannot drive other laptop apps yet.'
        : 'Add a model key to start. The key stays on this laptop.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
      if (!this.keyPresent && this.saved.length > 0) {
        Text(this.saved)
          .fontSize(11)
          .fontColor($r('app.color.danger'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  Turn(turn: LaptopTurn) {
    if (turn.role === 'user') {
      Row() {
        Blank()
        Text(turn.text)
          .fontSize(13.5)
          .lineHeight(21)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .constraintSize({ maxWidth: '62%' })
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
    } else {
      Row({ space: 12 }) {
        this.Mark(22)
        Column({ space: 6 }) {
          Text(turn.text)
            .fontSize(13.5)
            .lineHeight(22)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .copyOption(CopyOptions.LocalDevice)
          Text('HOPA · this laptop')
            .fontSize(9.5)
            .fontColor($r('app.color.text_hint'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ right: 40 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  build() {
    Column() {
      this.Header()
      if (this.settingsOpen) {
        this.SettingsPanel()
      }
      if (this.turns.length === 0) {
        Column() {
          this.Empty()
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.turns, (turn: LaptopTurn, index: number) => {
            ListItem() {
              this.Turn(turn)
            }
            .padding({ top: 10, bottom: 10 })
          }, (turn: LaptopTurn, index: number) => `${index}-${turn.role}`)
          if (this.busy) {
            ListItem() {
              Row({ space: 10 }) {
                this.Mark(18)
                Text('Thinking…')
                  .fontSize(12)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
            }
            .padding({ top: 8, bottom: 8 })
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 22, right: 22 })
        .scrollBar(BarState.Off)
      }
      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(10.5)
          .fontColor($r('app.color.danger'))
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 4 })
      }
      Row({ space: 10 }) {
        TextInput({ text: this.draft, placeholder: 'Ask HOPA…' })
          .layoutWeight(1)
          .height(44)
          .fontSize(13.5)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(22)
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => {
            this.draft = value;
          })
          .onSubmit(() => {
            this.send();
          })
        Button('Send')
          .height(44)
          .fontSize(13)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .enabled(!this.busy && this.draft.trim().length > 0)
          .onClick(() => {
            this.send();
          })
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
