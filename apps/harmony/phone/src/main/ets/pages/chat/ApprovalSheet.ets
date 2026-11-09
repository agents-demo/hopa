/**
 * The approval sheet: a bottom card that works over any page.
 *
 * It lives in the shell, not in Chat, so a run that moves to the Browser can
 * still ask before a sensitive action.
 */
import { HopaMark } from './HopaMark';

@Component
export struct ApprovalSheet {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop payment: boolean = false;
  /** Where the target sits in the captured screen, in device pixels. */
  @Prop highlightX1: number = 0;
  @Prop highlightY1: number = 0;
  @Prop highlightX2: number = 0;
  @Prop highlightY2: number = 0;
  @Prop frameWidth: number = 0;
  @Prop frameHeight: number = 0;
  @Prop highlightLabel: string = '';
  /** Non-empty when the app can be remembered for outgoing messages. */
  @Prop rememberLabel: string = '';
  @State understood: boolean = false;
  @State remember: boolean = false;
  onAllow: (remember: boolean) => void = () => {};
  onDeny: () => void = () => {};

  private hasCue(): boolean {
    return this.highlightX2 > this.highlightX1 &&
      this.frameWidth > 0 && this.frameHeight > 0;
  }

  private left(): string {
    return `${Math.max(0, this.highlightX1 / this.frameWidth * 100)}%`;
  }

  private top(): string {
    return `${Math.max(0, this.highlightY1 / this.frameHeight * 100)}%`;
  }

  private cueWidth(): string {
    const share: number = (this.highlightX2 - this.highlightX1) / this.frameWidth * 100;
    return `${Math.min(100, Math.max(5, share))}%`;
  }

  private cueHeight(): string {
    const share: number = (this.highlightY2 - this.highlightY1) / this.frameHeight * 100;
    return `${Math.min(100, Math.max(4, share))}%`;
  }

  @Builder
  Cue() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(10)
        Column()
          .width(this.cueWidth())
          .height(this.cueHeight())
          .position({ x: this.left(), y: this.top() })
          .border({ width: 2, color: $r('app.color.primary') })
          .borderRadius(7)
          .backgroundColor('#222F6FEB')
      }
      .width('100%')
      .height(92)
      .clip(true)

      if (this.highlightLabel.length > 0) {
        Text(`Highlighted: ${this.highlightLabel}`)
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim'))
      Column({ space: 12 }) {
        Row()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor($r('app.color.divider'))
          .margin({ bottom: 2 })
        Row({ space: 8 }) {
          HopaMark({ state: 'waiting', markSize: 28 })
          Text('HOPA')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
          if (!this.payment) {
            Text('PUBLIC')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary'))
              .backgroundColor($r('app.color.primary_soft'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          if (this.payment) {
            Text('PAYMENT')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.on_primary'))
              .backgroundColor($r('app.color.danger'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
        }
        .width('100%')
        Text(this.title)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.hasCue()) {
          this.Cue()
        }
        Scroll() {
          Text(this.message)
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .constraintSize({ maxHeight: 220 })
        .width('100%')
        .scrollBar(BarState.Off)
        if (this.payment) {
          Row({ space: 10 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.understood })
              .onChange((on: boolean) => {
                this.understood = on;
              })
            Text('I understand this spends money')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .alignItems(VerticalAlign.Center)
        }
        if (this.rememberLabel.length > 0) {
          Row({ space: 10 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.remember })
              .onChange((on: boolean) => {
                this.remember = on;
              })
            Text(`Always allow messages from ${this.rememberLabel}`)
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .alignItems(VerticalAlign.Center)
        }
        Row({ space: 10 }) {
          Button('Not now')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor($r('app.color.surface_muted'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.onDeny();
            })
          Button('Go ahead')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .enabled(!this.payment || this.understood)
            .backgroundColor(this.payment
              ? (this.understood ? $r('app.color.danger') : $r('app.color.surface_muted'))
              : $r('app.color.primary'))
            .fontColor(this.payment && !this.understood
              ? $r('app.color.text_hint')
              : $r('app.color.on_primary'))
            .onClick(() => {
              if (this.payment && !this.understood) {
                return;
              }
              this.onAllow(this.remember);
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 22 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius({ topLeft: 22, topRight: 22 })
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 420 })))
  }
}
