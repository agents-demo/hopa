/**
 * The approval sheet: a bottom card that works over any page.
 *
 * It lives in the shell, not in Chat, so a run that moves to the Browser can
 * still ask before a sensitive action.
 */
@Component
export struct ApprovalSheet {
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop payment: boolean = false;
  onAllow: () => void = () => {};
  onDeny: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim'))
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Text('HOPA')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
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
        Scroll() {
          Text(this.message)
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .constraintSize({ maxHeight: 260 })
        .width('100%')
        .scrollBar(BarState.Off)
        Row({ space: 10 }) {
          Button('Deny')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor($r('app.color.surface_muted'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.onDeny();
            })
          Button('Allow')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor(this.payment ? $r('app.color.danger') : $r('app.color.primary'))
            .fontColor($r('app.color.on_primary'))
            .onClick(() => {
              this.onAllow();
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
  }
}
