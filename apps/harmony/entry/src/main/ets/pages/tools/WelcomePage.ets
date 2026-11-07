/** First-run walkthrough. The parent owns navigation. */
@Component
export struct WelcomePage {
  onOpenSettings: () => void = () => {};
  onOpenChat: () => void = () => {};

  build() {
    Column({ space: 14 }) {
      Text('Three steps and HOPA is ready.')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text('1. Add a model')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('Settings -> provider, endpoint, model and key. The key is kept in memory only.')
        .fontSize(12)
        .fontColor('#666666')
      Text('2. Give it a screen')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('Enable the accessibility service on a device that allows it, or connect the PC bridge for tethered control.')
        .fontSize(12)
        .fontColor('#666666')
      Text('3. Ask in Chat')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('"Open Settings and turn on Wi-Fi." Every action passes the payment gate, and every result is recorded.')
        .fontSize(12)
        .fontColor('#666666')
      Row({ space: 8 }) {
        Button('Open Settings')
          .fontSize(12)
          .onClick(() => {
            this.onOpenSettings();
          })
        Button('Open Chat')
          .fontSize(12)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            this.onOpenChat();
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
