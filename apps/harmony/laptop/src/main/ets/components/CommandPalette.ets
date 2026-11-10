/**
 * The command palette: a scrim and a short list of actions.
 *
 * The page decides whether it is open; this decides what it contains. No
 * service access, so it stays testable by looking at it.
 */
@Component
export struct CommandPalette {
  onNewChat: () => void = () => {};
  onSettings: () => void = () => {};
  onClose: () => void = () => {};

  @Builder
  Row(label: string, action: () => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
      Blank()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .borderRadius(9)
    .onClick(() => {
      action();
      this.onClose();
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#33000000')
        .onClick(() => {
          this.onClose();
        })
      Column({ space: 2 }) {
        Text('Commands')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.7)
          .width('100%')
          .padding({ left: 12, bottom: 6 })
        this.Row('New chat', () => {
          this.onNewChat();
        })
        this.Row('Settings', () => {
          this.onSettings();
        })
        this.Row('Close', () => {})
      }
      .width(420)
      .padding(10)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .shadow({ radius: 24, color: '#33000000', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
