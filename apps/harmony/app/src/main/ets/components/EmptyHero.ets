import { HopaMark } from './HopaMark';

/**
 * The hero every shell starts from: the same mark, greeting, wordmark,
 * tagline and the payment promise. Size and copy are props, so the phone and
 * the laptop share the composition without sharing a screen.
 */
@Component
export struct EmptyHero {
  @Prop greeting: string = '';
  @Prop tagline: string = '';
  /** The promise that must never be dropped, on any shell. */
  @Prop promise: string = '';
  /** A build note under the promise; empty on the phone. */
  @Prop note: string = '';
  @Prop titleSize: number = 34;
  @Prop bodySize: number = 15;
  @Prop markSize: number = 92;
  @Prop animate: boolean = true;
  @Prop interactive: boolean = true;

  build() {
    Column({ space: 12 }) {
      HopaMark({
        state: 'idle',
        markSize: this.markSize,
        animate: this.animate,
        interactive: this.interactive
      })
      if (this.greeting.length > 0) {
        Text(this.greeting)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.4)
      }
      Text('HOPA')
        .fontSize(this.titleSize)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .letterSpacing(-0.4)
      Text(this.tagline)
        .fontSize(this.bodySize - 1)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      if (this.promise.length > 0) {
        Text(this.promise)
          .fontSize(this.bodySize - 4)
          .fontColor($r('app.color.text_hint'))
          .textAlign(TextAlign.Center)
      }
      if (this.note.length > 0) {
        Text(this.note)
          .fontSize(this.bodySize - 5)
          .fontColor($r('app.color.text_hint'))
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
