/** Compact copy/retry actions for the latest message, icon-first. */
@Component
export struct MessageActions {
  @Prop showRetry: boolean = false;
  onCopy: () => void = () => {};
  onRetry: () => void = () => {};

  @Builder
  CopyIcon() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: $r('app.color.primary') })
        .borderRadius(2)
        .offset({ x: 3, y: 3 })
      Column()
        .width(8)
        .height(10)
        .border({ width: 1.3, color: $r('app.color.primary') })
        .borderRadius(2)
        .backgroundColor($r('app.color.bg'))
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
          Text('↻')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
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
  }
}
