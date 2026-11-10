/**
 * The right rail: live facts about the current answer, and the honest limits.
 *
 * It is a dumb component on purpose: the page owns the data, this owns the
 * layout, so neither drifts into the other.
 */
@Component
export struct ChatRail {
  @Prop lastQuestion: string = '';
  @Prop lastLatency: number = 0;
  @Prop lastTokens: number = 0;
  @Prop hasTurns: boolean = false;

  @Builder
  Label(text: string) {
    Text(text)
      .fontSize(9)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.8)
      .width('100%')
  }

  build() {
    Column() {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          this.Label('THIS CONVERSATION')
          Text(this.lastQuestion.length > 0 ? this.lastQuestion : 'No question yet.')
            .fontSize(12.5)
            .lineHeight(18)
            .fontColor(this.lastQuestion.length > 0
              ? $r('app.color.text_primary')
              : $r('app.color.text_hint'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.lastLatency > 0
            ? `${this.lastLatency} ms  \u00b7  ${this.lastTokens} tokens`
            : 'No answer yet')
            .fontSize(10.5)
            .fontColor($r('app.color.text_hint'))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Divider().color($r('app.color.divider'))

        Column({ space: 6 }) {
          this.Label('WHAT HOPA SEES')
          Text(this.hasTurns
            ? 'The conversation only. HOPA runs here, on this machine; it does not read the screen or drive other apps yet.'
            : 'Your words only. HOPA runs here, on this machine; it cannot drive other laptop apps yet.')
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text('Payments always ask first.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .width('100%')
        .padding({ bottom: 2 })
    }
    .width(258)
    .height('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 14 })
    .backgroundColor($r('app.color.surface_alt'))
    .border({ width: { left: 1 }, color: $r('app.color.divider') })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
  }
}
