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
  /** Older transcript avatars stay still; only the live one breathes. */
  @Prop animate: boolean = true;
  @State pulse: boolean = false;
  @State blink: boolean = false;
  @State cheer: boolean = false;
  @State bob: boolean = false;
  private timer: number = -1;
  private blinkTimer: number = -1;
  private cheerTimer: number = -1;
  private bobTimer: number = -1;

  aboutToAppear(): void {
    if (!this.animate) {
      return;
    }
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
    this.bobTimer = setInterval(() => {
      this.bob = !this.bob;
    }, 2200);
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
    if (this.bobTimer >= 0) {
      clearInterval(this.bobTimer);
      this.bobTimer = -1;
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
    if (this.state === 'happy') {
      return this.markSize * 0.035;
    }
    if (this.state === 'error') {
      return this.markSize * 0.03;
    }
    return this.markSize * 0.1;
  }

  private armAngle(): number {
    if (this.cheer || this.state === 'acting' || this.state === 'happy') {
      return -38;
    }
    if (this.state === 'waiting') {
      return -22;
    }
    if (this.state === 'idle') {
      return this.bob ? -28 : -16;
    }
    return 12;
  }

  private armY(): number {
    if (this.cheer || this.state === 'acting' || this.state === 'happy') {
      return -this.markSize * 0.1;
    }
    if (this.state === 'idle' || this.state === 'waiting') {
      return -this.markSize * 0.06;
    }
    return this.markSize * 0.02;
  }

  /** A smile that reads at both 22 dp and 64 dp. */
  private mouthPath(): string {
    const w: number = this.markSize * 0.18;
    const h: number = this.markSize * 0.08;
    if (this.state === 'error') {
      return `M 0 ${h} Q ${w / 2} 0 ${w} ${h}`;
    }
    return `M 0 0 Q ${w / 2} ${h} ${w} 0`;
  }

  private label(): string {
    if (this.state === 'thinking' || this.state === 'acting') {
      return 'HOPA is working';
    }
    if (this.state === 'waiting') {
      return 'HOPA is waiting for your approval';
    }
    if (this.state === 'happy') {
      return 'HOPA finished';
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
          Path()
            .width(this.markSize * 0.18)
            .height(this.markSize * 0.08)
            .commands(this.mouthPath())
            .stroke($r('app.color.text_primary'))
            .strokeWidth(this.markSize * 0.025)
            .strokeLineCap(LineCapStyle.Round)
            .fill(Color.Transparent)
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
    .scale({
      x: this.cheer || this.state === 'happy' ? 1.06 : 1,
      y: this.cheer || this.state === 'happy' ? 1.06 : 1
    })
    .animation({ duration: 300, curve: Curve.EaseOut })
    .offset({
      y: this.state === 'idle' || this.state === 'waiting'
        ? (this.bob ? this.markSize * 0.025 : -this.markSize * 0.025)
        : 0
    })
    .animation({ duration: 1100, curve: Curve.EaseInOut })
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
