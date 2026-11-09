import { Context } from '@kit.AbilityKit';
import { Character } from '../../services/Character';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** The persona sheet: who HOPA is, how warm, how chatty. */
@Component
export struct CharacterPage {
  @State tone: string = 'warm';
  @State chattiness: string = 'balanced';
  @State quips: boolean = true;
  @State tactile: boolean = true;
  @State address: string = '';
  @State loaded: boolean = false;

  aboutToAppear(): void {
    SettingsStore.load(getContext(this) as Context).then((stored: StoredSettings) => {
      Character.configure(stored);
      this.tone = stored.tone;
      this.chattiness = stored.chattiness;
      this.quips = stored.quips;
      this.tactile = stored.tactile;
      this.address = stored.address;
      this.loaded = true;
    }).catch(() => {
      this.loaded = true;
    });
  }

  private save(): void {
    Character.tone = this.tone;
    Character.chattiness = this.chattiness;
    Character.quips = this.quips;
    Character.tactile = this.tactile;
    Character.address = this.address.trim();
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.tone = this.tone;
      stored.chattiness = this.chattiness;
      stored.quips = this.quips;
      stored.tactile = this.tactile;
      stored.address = this.address.trim();
      return SettingsStore.save(context, stored);
    }).catch(() => {
      // In-memory persona still applies this session.
    });
  }

  private preview(): string {
    Character.tone = this.tone;
    return Character.sample();
  }

  @Builder
  Segmented(labels: string[], values: string[], selected: string, onPick: (value: string) => void) {
    Row({ space: 6 }) {
      ForEach(labels, (label: string, index: number) => {
        Text(label)
          .fontSize(13)
          .fontWeight(selected === values[index] ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(selected === values[index]
            ? $r('app.color.on_primary')
            : $r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
          .height(34)
          .layoutWeight(1)
          .backgroundColor(selected === values[index]
            ? $r('app.color.primary')
            : $r('app.color.surface_muted'))
          .borderRadius(17)
          .onClick(() => {
            onPick(values[index]);
          })
      }, (label: string, index: number) => `${label}-${index}`)
    }
    .width('100%')
  }

  @Builder
  Card(title: string, body: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(body)
        .fontSize(11.5)
        .lineHeight(18)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 6 }) {
        Text('HOPA')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('Your phone agent. Adult, capable, a little dry.')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 7 }) {
        ForEach(Character.PRINCIPLES, (line: string) => {
          Row({ space: 8 }) {
            Text('·')
              .fontSize(14)
              .fontColor($r('app.color.primary'))
            Text(line)
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (line: string) => line)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)

      Text('WHAT HOPA CALLS YOU')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.6)
        .padding({ top: 2 })
      TextInput({ text: this.address, placeholder: 'Optional. Leave empty for no name.' })
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(12)
        .onChange((value: string) => {
          this.address = value;
        })
        .onSubmit(() => {
          this.save();
        })

      Text('TONE')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.6)
        .padding({ top: 2 })
      this.Segmented(Character.TONE_LABELS, Character.TONES, this.tone, (value: string) => {
        this.tone = value;
        this.save();
      })
      Text('Warm is attentive, Balanced is neutral, Direct is shorthand.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))

      Text('CHATTINESS')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.6)
        .padding({ top: 6 })
      this.Segmented(Character.CHATTER_LABELS, Character.CHATTER, this.chattiness, (value: string) => {
        this.chattiness = value;
        this.save();
      })

      Column({ space: 8 }) {
        Row({ space: 10 }) {
          Text('Dry one-liners')
            .fontSize(13.5)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.quips })
            .onChange((on: boolean) => {
              this.quips = on;
              this.save();
            })
        }
        .width('100%')
        Divider().color($r('app.color.divider'))
        Row({ space: 10 }) {
          Text('Tactile feedback')
            .fontSize(13.5)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.tactile })
            .onChange((on: boolean) => {
              this.tactile = on;
              this.save();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 4, bottom: 4 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(16)

      Text('PREVIEW')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.6)
        .padding({ top: 4 })
      Column({ space: 4 }) {
        Text(this.preview())
          .fontSize(13.5)
          .lineHeight(20)
          .fontColor($r('app.color.text_primary'))
        Text('One run, in this voice.')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.primary_soft'))
      .borderRadius(14)
      .alignItems(HorizontalAlign.Start)

      Text('Payments always ask, in every voice. That cannot be switched off.')
        .fontSize(10)
        .lineHeight(16)
        .fontColor($r('app.color.text_hint'))
        .padding({ top: 2 })
    }
    .width('100%')
    .padding({ top: 4, bottom: 24 })
    .alignItems(HorizontalAlign.Start)
  }
}
