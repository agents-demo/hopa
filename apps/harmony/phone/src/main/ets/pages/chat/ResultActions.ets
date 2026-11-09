/** Actions attached to the latest answer: copy, share, remember. */
@Component
export struct ResultActions {
  onCopy: () => void = () => {};
  onShare: () => void = () => {};
  onRemember: () => void = () => {};

  @Builder
  Action(label: string, action: () => void) {
    Text(label)
      .fontSize(10.5)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.primary'))
      .height(26)
      .padding({ left: 10, right: 10 })
      .backgroundColor($r('app.color.primary_soft'))
      .borderRadius(13)
      .onClick(action)
  }

  build() {
    Row({ space: 6 }) {
      this.Action('Copy', this.onCopy)
      this.Action('Share', this.onShare)
      this.Action('Remember', this.onRemember)
    }
    .width('100%')
    .padding({ left: 2, top: 2 })
  }
}
