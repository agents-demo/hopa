/** The first screen of a new chat: brand, promise and three suggestions. */
import { HopaMark } from './HopaMark';

@Component
export struct ChatEmptyState {
  onPick: (text: string) => void = () => {};

  private suggestions(): string[] {
    return [
      'Open Bilibili and show me the 3 most popular videos',
      'Open Settings and show me Wi-Fi',
      'Draft a one-line message to my team'
    ];
  }

  build() {
    Column({ space: 10 }) {
      HopaMark({ state: 'idle', markSize: 64 })
      Text('HOPA')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('Your phone agent. Ask for something on this phone.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Text('I always ask before any payment.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 6 }) {
        ForEach(this.suggestions(), (suggestion: string) => {
          Row() {
            Text(suggestion)
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick(() => {
            this.onPick(suggestion);
          })
        }, (suggestion: string) => suggestion)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
  }
}
