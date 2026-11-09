/** First-run walkthrough. The parent owns navigation. */
import { HopaMark } from '../chat/HopaMark';

@Component
export struct WelcomePage {
  onOpenSettings: () => void = () => {};
  onOpenChat: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      HopaMark({ state: 'idle', markSize: 72 })
        .margin({ top: 8 })
      Text('Hi, I\'m HOPA.')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('A phone agent that can open apps, read the screen and tap for you.')
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('app.color.text_secondary'))
      Column({ space: 8 }) {
        Text('1. Add a model')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text('Provider, endpoint, model and key in Settings. The key stays in memory and is never shown again.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
        Text('2. Give it a screen')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text('Enable the accessibility service on a device that allows it, or connect the PC bridge for tethered control.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
        Text('3. Ask in Chat')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text('"Open Settings and turn on Wi-Fi." Every action passes the payment gate, and every result is recorded.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: 6 })
      Row({ space: 8 }) {
        Button('Open Settings')
          .fontSize(12)
          .onClick(() => {
            this.onOpenSettings();
          })
        Button('Open Chat')
          .fontSize(12)
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.onOpenChat();
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
  }
}
