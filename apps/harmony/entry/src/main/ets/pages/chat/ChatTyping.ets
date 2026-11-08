import { HopaMark } from './HopaMark';

/** The "HOPA is working" row with the living mark and three breathing dots. */
@Component
export struct ChatTyping {
  @State pulse: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      this.pulse = !this.pulse;
    }, 450);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private dotOpacity(offset: boolean): number {
    return this.pulse === offset ? 1 : 0.3;
  }

  build() {
    Row({ space: 8 }) {
      HopaMark({ state: 'thinking', markSize: 24 })
      Row({ space: 4 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(false))
          .animation({ duration: 380, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(true))
          .animation({ duration: 380, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(false))
          .animation({ duration: 380, curve: Curve.EaseInOut })
      }
    }
    .width('100%')
    .padding({ left: 4, top: 10, bottom: 10 })
  }
}
