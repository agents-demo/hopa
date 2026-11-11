import { Context } from '@kit.AbilityKit';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** A four-digit PIN that gates Settings from Kid mode. */
@Component
export struct ParentPinPage {
  @State pin: string = '';
  @State draft: string = '';
  @State hasPin: boolean = false;
  @State saved: string = '';

  aboutToAppear(): void {
    SettingsStore.load(getContext(this) as Context).then((stored: StoredSettings) => {
      this.pin = stored.kidPin;
      this.hasPin = this.pin.length > 0;
    }).catch(() => {
      // No PIN is set.
    });
  }

  private save(): void {
    const clean: string = this.draft.trim();
    if (clean.length !== 4 || !/^\d{4}$/.test(clean)) {
      this.saved = 'Use four digits.';
      return;
    }
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.kidPin = clean;
      return SettingsStore.save(context, stored);
    }).then(() => {
      this.pin = clean;
      this.hasPin = true;
      this.draft = '';
      this.saved = 'PIN saved.';
    }).catch(() => {
      this.saved = 'Could not save the PIN.';
    });
  }

  private remove(): void {
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.kidPin = '';
      return SettingsStore.save(context, stored);
    }).then(() => {
      this.pin = '';
      this.hasPin = false;
      this.saved = 'PIN removed.';
    }).catch(() => {
      this.saved = 'Could not remove the PIN.';
    });
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Text(this.hasPin
          ? 'Settings in Kid mode asks for this PIN. Payments still ask separately.'
          : 'Set a four-digit PIN so a child cannot leave Kid mode through Settings.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        Column({ space: 8 }) {
          Text(this.hasPin ? 'Change PIN' : 'Set a PIN')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
          TextInput({ text: this.draft, placeholder: '4 digits' })
            .type(InputType.Number)
            .maxLength(4)
            .height(42)
            .fontSize(15)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(10)
            .onChange((value: string) => {
              this.draft = value;
              this.saved = '';
            })
          Row({ space: 8 }) {
            Text(this.hasPin ? 'Save new PIN' : 'Save PIN')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(9)
              .onClick(() => {
                this.save();
              })
            if (this.hasPin) {
              Text('Remove PIN')
                .fontSize(12)
                .fontColor($r('app.color.danger'))
                .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                .backgroundColor($r('app.color.surface_muted'))
                .borderRadius(9)
                .onClick(() => {
                  this.remove();
                })
            }
          }
          .width('100%')
          if (this.saved.length > 0) {
            Text(this.saved)
              .fontSize(11)
              .fontColor(this.saved === 'PIN saved.' || this.saved === 'PIN removed.'
                ? $r('app.color.success')
                : $r('app.color.warning'))
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)
        .alignItems(HorizontalAlign.Start)

        Text('The PIN is stored on this phone only. HOPA asks before any payment in every mode.')
          .fontSize(10)
          .lineHeight(16)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding({ top: 4, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
