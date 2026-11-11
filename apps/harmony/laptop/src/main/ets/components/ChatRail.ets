/**
 * The right rail: live facts about the current answer, and the honest limits.
 *
 * It is a dumb component on purpose: the page owns the data, this owns the
 * layout, so neither drifts into the other.
 */
@Component
export struct ChatRail {
  @Prop lastLatency: number = 0;
  @Prop lastTokens: number = 0;
  /** True when a PC bridge is configured, so the screen is really readable. */
  @Prop bridgeLive: boolean = false;
  @Prop metrics: boolean = true;
  @Prop approvalOpen: boolean = false;
  @Prop approvalDetail: string = '';
  /** The last frame the bridge captured before this step: evidence, not decoration. */
  @Prop approvalFrame: string = '';
  onAllow: () => void = () => {};
  onDeny: () => void = () => {};

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
        if (this.approvalOpen) {
          Column({ space: 8 }) {
            this.Label('YOUR OK')
            if (this.approvalFrame.length > 0) {
              Column({ space: 4 }) {
                this.Label('WHAT HOPA SAW')
                Image(this.approvalFrame)
                  .width('100%')
                  .height(88)
                  .objectFit(ImageFit.Cover)
                  .borderRadius(7)
                  .border({ width: 1, color: $r('app.color.divider') })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }
            Text(this.approvalDetail)
              .fontSize(12.5)
              .lineHeight(18)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Row({ space: 8 }) {
              Text('Not now')
                .fontSize(11.5)
                .fontColor($r('app.color.text_primary'))
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .backgroundColor($r('app.color.surface_muted'))
                .borderRadius(14)
                .onClick(() => {
                  this.onDeny();
                })
              Text('Allow')
                .fontSize(11.5)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_primary'))
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .backgroundColor($r('app.color.primary'))
                .borderRadius(14)
                .onClick(() => {
                  this.onAllow();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(10)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(10)
          .border({ width: 1, color: $r('app.color.primary_soft') })
          .alignItems(HorizontalAlign.Start)

          Divider().color($r('app.color.divider'))
        }

        // Facts the centre pane does not already show: how long the answer
        // took and what it cost, and only when they were actually measured.
        // Echoing the user's own words here was just a second copy of the chat.
        if (this.metrics && this.lastLatency > 0) {
          Column({ space: 6 }) {
            this.Label('THIS ANSWER')
            Text(`${(this.lastLatency / 1000).toFixed(1)} s  \u00b7  ${this.lastTokens} tokens`)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Divider().color($r('app.color.divider'))
        }

        Column({ space: 6 }) {
          this.Label('WHAT HOPA SEES')
          Text(this.bridgeLive
            ? 'PC bridge connected. HOPA can read this screen when you ask, and every action asks first.'
            : 'PC bridge not connected. HOPA sees only this conversation; connect the bridge in Settings to let it read the screen.')
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
