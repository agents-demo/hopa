/** The first screen of a new chat: brand, promise and three suggestions. */
import { HopaMark } from './HopaMark';
import { AgentService } from '../../services/AgentService';
import { SettingsStore } from '../../services/SettingsStore';
import { Context } from '@kit.AbilityKit';

@Component
export struct ChatEmptyState {
  onPick: (text: string) => void = () => {};
  @Prop resume: string = '';
  @Prop listening: boolean = false;
  @State entered: boolean = false;
  @State pressed: number = -1;
  @State greeting: string = 'Hi';

  aboutToAppear(): void {
    const hour: number = new Date().getHours();
    this.greeting = hour < 5 ? 'Still up?' : (hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening'));
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored) => {
      if (stored.reduceMotion) {
        this.entered = true;
      }
    }).catch(() => {
      // Keep the default animation.
    });
    // A soft entrance: content lifts in instead of appearing fully formed.
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.entered = true;
    });
  }

  private suggestions(): string[] {
    return [
      'Open Bilibili and show me the 3 most popular videos',
      'Open Settings and show me Wi-Fi',
      'Draft a one-line message to my team'
    ];
  }

  private pick(index: number, text: string): void {
    this.pressed = index;
    setTimeout(() => {
      this.pressed = -1;
    }, 140);
    this.onPick(text);
  }

  build() {
    Column({ space: 12 }) {
      HopaMark({ state: this.listening ? 'listening' : 'idle', markSize: 64 })
      Text(this.greeting)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.4)
      Text('HOPA')
        .fontSize(27)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .letterSpacing(-0.4)
      Text('Your phone agent. Ask for something on this phone.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Text('I always ask before any payment.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 8 }) {
        if (this.resume.length > 0 && !this.suggestions().includes(this.resume)) {
          Row({ space: 8 }) {
            Text('RESUME')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary'))
              .letterSpacing(0.6)
              .padding({ left: 6, right: 6, top: 3, bottom: 3 })
              .backgroundColor('#1AE8703A')
              .borderRadius(6)
            Text(this.resume)
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 10, right: 12, top: 9, bottom: 9 })
          .border({ width: 1, color: '#26E8703A' })
          .borderRadius(12)
          .opacity(this.pressed === -1 ? 1 : 0.62)
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onClick(() => {
            this.pick(-1, this.resume);
          })
        }
        ForEach(this.suggestions(), (suggestion: string, index: number) => {
          Row() {
            Text(suggestion)
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: '#0F1C1B18' })
          .borderRadius(12)
          .shadow({ radius: 10, color: '#0A1C1B18', offsetY: 2 })
          .scale({ x: this.pressed === index ? 0.985 : 1, y: this.pressed === index ? 0.985 : 1 })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onClick(() => {
            this.pick(index, suggestion);
          })
        }, (suggestion: string) => suggestion)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .opacity(this.entered ? 1 : 0)
    .translate({ y: this.entered ? 0 : 10 })
    .animation({ duration: 420, curve: Curve.EaseOut })
  }
}
