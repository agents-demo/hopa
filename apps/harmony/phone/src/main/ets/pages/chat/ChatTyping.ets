import { HopaMark } from './HopaMark';
import { SettingsStore } from '../../services/SettingsStore';
import { Context } from '@kit.AbilityKit';

/** The "HOPA is working" row with the living mark and three breathing dots. */
@Component
export struct ChatTyping {
  @State phase: number = 0;
  @State calm: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored) => {
      this.calm = stored.reduceMotion;
    }).catch(() => {
      // Animate by default.
    });
    this.timer = setInterval(() => {
      if (!this.calm) {
        this.phase = (this.phase + 1) % 3;
      }
    }, 280);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** A wave: the active dot is brightest, the next one trails behind. */
  private dotOpacity(index: number): number {
    if (this.calm) {
      return 0.55;
    }
    if (this.phase === index) {
      return 1;
    }
    if ((this.phase + 2) % 3 === index) {
      return 0.55;
    }
    return 0.25;
  }

  build() {
    Row({ space: 8 }) {
      HopaMark({ state: 'thinking', markSize: 26, interactive: false })
      Row({ space: 4 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(0))
          .animation({ duration: 240, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(1))
          .animation({ duration: 240, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.dotOpacity(2))
          .animation({ duration: 240, curve: Curve.EaseInOut })
      }
    }
    .width('100%')
    .padding({ left: 4, top: 10, bottom: 10 })
  }
}
