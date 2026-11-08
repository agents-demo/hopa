/**
 * HOPA, the living phone: a coral phone body, a pale screen face, two feet
 * and one arm that taps. The silhouette is a phone; the face is the agent.
 *
 * Drawn from shapes so it stays sharp at 24 dp and 64 dp, and so the timer and
 * blink work without an image asset.
 */
import { Haptics } from '../../services/Haptics';

@Component
export struct HopaMark {
  @Prop state: string = 'idle';
  @Prop markSize: number = 32;
  @State pulse: boolean = false;
  @State blink: boolean = false;
  @State cheer: boolean = false;
  private timer: number = -1;
  private blinkTimer: number = -1;
  private cheerTimer: number = -1;

  aboutToAppear(): void {
    if (this.state === 'thinking' || this.state === 'acting') {
      this.timer = setInterval(() => {
        this.pulse = !this.pulse;
      }, 520);
    }
    this.blinkTimer = setInterval(() => {
      this.blink = true;
      setTimeout(() => {
        this.blink = false;
      }, 150);
    }, 4200);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.blinkTimer >= 0) {
      clearInterval(this.blinkTimer);
      this.blinkTimer = -1;
    }
    if (this.cheerTimer >= 0) {
      clearTimeout(this.cheerTimer);
      this.cheerTimer = -1;
    }
  }

  private eyeHeight(): number {
    if (this.blink) {
      return this.markSize * 0.02;
    }
    if (this.state === 'waiting') {
      return this.markSize * 0.12;
    }
    if (this.state === 'thinking' || this.state === 'acting') {
      return this.markSize * 0.07;
    }
    if (this.state === 'error') {
      return this.markSize * 0.03;
    }
    return this.markSize * 0.1;
  }

  private armAngle(): number {
    if (this.cheer || this.state === 'acting') {
      return -38;
    }
    if (this.state === 'waiting') {
      return -5;
    }
    return 12;
  }

  private armY(): number {
    return this.cheer || this.state === 'acting' ? -this.markSize * 0.1 : this.markSize * 0.02;
  }

  private label(): string {
    if (this.state === 'thinking' || this.state === 'acting') {
      return 'HOPA is working';
    }
    if (this.state === 'waiting') {
      return 'HOPA is waiting for your approval';
    }
    if (this.state === 'error') {
      return 'HOPA could not finish';
    }
    return 'HOPA';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row({ space: this.markSize * 0.1 }) {
        Column()
          .width(this.markSize * 0.12)
          .height(this.markSize * 0.06)
          .borderRadius(this.markSize * 0.03)
          .backgroundColor($r('app.color.accent'))
        Column()
          .width(this.markSize * 0.12)
          .height(this.markSize * 0.06)
          .borderRadius(this.markSize * 0.03)
          .backgroundColor($r('app.color.accent'))
      }
      .offset({ y: this.markSize * 0.42 })

      Column()
        .width(this.markSize * 0.075)
        .height(this.markSize * 0.26)
        .borderRadius(this.markSize * 0.04)
        .backgroundColor($r('app.color.accent'))
        .offset({ x: this.markSize * 0.36, y: this.armY() })
        .rotate({ angle: this.armAngle() })
        .animation({ duration: 260, curve: Curve.EaseOut })

      Column()
        .width(this.markSize * 0.62)
        .height(this.markSize * 0.82)
        .borderRadius(this.markSize * 0.18)
        .backgroundColor($r('app.color.accent'))
        .offset({ y: -this.markSize * 0.04 })

      Column({ space: this.markSize * 0.035 }) {
        if (this.state === 'thinking' || this.state === 'acting') {
          Row({ space: this.markSize * 0.05 }) {
            Column()
              .width(this.markSize * 0.035)
              .height(this.markSize * 0.035)
              .borderRadius(this.markSize * 0.018)
              .backgroundColor($r('app.color.text_primary'))
              .opacity(this.pulse ? 1 : 0.45)
            Column()
              .width(this.markSize * 0.035)
              .height(this.markSize * 0.035)
              .borderRadius(this.markSize * 0.018)
              .backgroundColor($r('app.color.text_primary'))
              .opacity(this.pulse ? 0.45 : 1)
            Column()
              .width(this.markSize * 0.035)
              .height(this.markSize * 0.035)
              .borderRadius(this.markSize * 0.018)
              .backgroundColor($r('app.color.text_primary'))
              .opacity(this.pulse ? 1 : 0.45)
          }
        } else {
          Row({ space: this.markSize * 0.14 }) {
            Column()
              .width(this.markSize * 0.055)
              .height(this.eyeHeight())
              .borderRadius(this.markSize * 0.03)
              .backgroundColor($r('app.color.text_primary'))
              .animation({ duration: 120, curve: Curve.EaseOut })
            Column()
              .width(this.markSize * 0.055)
              .height(this.eyeHeight())
              .borderRadius(this.markSize * 0.03)
              .backgroundColor($r('app.color.text_primary'))
              .animation({ duration: 120, curve: Curve.EaseOut })
          }
          Row()
            .width(this.markSize * (this.state === 'waiting' ? 0.18 : 0.13))
            .height(this.markSize * 0.025)
            .borderRadius(this.markSize * 0.015)
            .backgroundColor($r('app.color.text_primary'))
            .opacity(this.state === 'error' ? 0.6 : 1)
        }
      }
      .width(this.markSize * 0.48)
      .height(this.markSize * 0.52)
      .borderRadius(this.markSize * 0.12)
      .backgroundColor($r('app.color.bg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .offset({ y: -this.markSize * 0.06 })
    }
    .width(this.markSize)
    .height(this.markSize)
    .opacity(this.state === 'error' ? 0.65 : (this.pulse ? 0.84 : 1))
    .scale({ x: this.cheer ? 1.06 : 1, y: this.cheer ? 1.06 : 1 })
    .animation({ duration: 300, curve: Curve.EaseOut })
    .onClick(() => {
      Haptics.tap();
      this.cheer = true;
      if (this.cheerTimer >= 0) {
        clearTimeout(this.cheerTimer);
      }
      this.cheerTimer = setTimeout(() => {
        this.cheer = false;
      }, 260);
      if (this.state === 'idle') {
        this.getUIContext().getPromptAction().showToast({ message: "Hi, I'm HOPA." });
      }
    })
    .accessibilityText(this.label())
  }
}
