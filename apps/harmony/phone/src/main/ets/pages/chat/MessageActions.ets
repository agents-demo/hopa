/** Compact copy/retry actions for the latest message, icon-first. */
@Component
export struct MessageActions {
  @Prop showRetry: boolean = false;
  @Prop muted: boolean = false;
  @State pressed: boolean = false;
  onCopy: () => void = () => {};
  onRetry: () => void = () => {};

  @Builder
  CopyIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: this.muted ? $r('app.color.text_secondary') : $r('app.color.primary') })
        .borderRadius(2)
        .offset({ x: 3, y: 3 })
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: this.muted ? $r('app.color.text_secondary') : $r('app.color.primary') })
        .borderRadius(2)
        .backgroundColor($r('app.color.bg'))
    }
    .width(14)
    .height(14)
  }

  @Builder
  RetryIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      // Ring with a gap, drawn at the same stroke weight as the copy icon.
      Column()
        .width(12)
        .height(12)
        .borderRadius(6)
        .border({ width: 1.3, color: this.muted ? $r('app.color.text_secondary') : $r('app.color.primary') })
        .offset({ x: 1, y: 1 })
      Column()
        .width(5.5)
        .height(5.5)
        .backgroundColor($r('app.color.bg'))
        .offset({ x: 9, y: 0 })
      // Arrowhead closing the gap.
      Column()
        .width(4.6)
        .height(4.6)
        .backgroundColor(this.muted ? $r('app.color.text_secondary') : $r('app.color.primary'))
        .rotate({ angle: 45 })
        .offset({ x: 8.2, y: 0.4 })
    }
    .width(14)
    .height(14)
  }

  build() {
    Row({ space: 4 }) {
      Row() {
        this.CopyIcon()
      }
      .width(26)
      .height(26)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .accessibilityText('Copy')
      .onClick(() => {
        this.onCopy();
      })
      if (this.showRetry) {
        Row() {
          this.RetryIcon()
        }
        .width(26)
        .height(26)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .accessibilityText('Retry')
        .onClick(() => {
          this.onRetry();
        })
      }
    }
    .alignItems(VerticalAlign.Center)
    .scale({ x: this.pressed ? 0.9 : 1, y: this.pressed ? 0.9 : 1 })
    .animation({ duration: 110, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
  }
}
