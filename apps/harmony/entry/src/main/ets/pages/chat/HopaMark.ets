/**
 * HOPA, the living phone. The character is the same SVG used in the README
 * banner, so the app and the artwork cannot drift apart. The bob, blink and
 * cheer are applied around the image.
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
  @State waveStep: number = 0;
  private timer: number = -1;
  private blinkTimer: number = -1;
  private cheerTimer: number = -1;
  private bobTimer: number = -1;
  private waveTimer: number = -1;

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
    if (this.waveTimer >= 0) {
      clearInterval(this.waveTimer);
      this.waveTimer = -1;
    }
  }

  private armAngle(): number {
    if (this.waveStep === 0) {
      return 45;
    }
    return this.waveStep % 2 === 1 ? 65 : 25;
  }

  private wave(): void {
    if (this.waveTimer >= 0) {
      clearInterval(this.waveTimer);
    }
    this.waveStep = 1;
    this.waveTimer = setInterval(() => {
      if (this.waveStep >= 7) {
        clearInterval(this.waveTimer);
        this.waveTimer = -1;
        this.waveStep = 0;
      } else {
        this.waveStep += 1;
      }
    }, 180);
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
      Image($r('app.media.hopa_body'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)

      // The arm is a separate layer so it can wave on tap.
      Column()
        .width(this.markSize * 0.062)
        .height(this.markSize * 0.20)
        .borderRadius(this.markSize * 0.031)
        .backgroundColor($r('app.color.accent'))
        .position({ x: this.markSize * 0.713, y: this.markSize * 0.281 })
        .rotate({ angle: this.armAngle() })
        .animation({ duration: 110, curve: Curve.EaseInOut })

      // Closed eyelids: the same cream as the screen face in the SVG.
      Column()
        .width(this.markSize * 0.051)
        .height(this.markSize * 0.113)
        .borderRadius(this.markSize * 0.03)
        .backgroundColor('#FFF9F0')
        .position({ x: this.markSize * 0.414, y: this.markSize * 0.398 })
        .opacity(this.blink ? 1 : 0)
      Column()
        .width(this.markSize * 0.051)
        .height(this.markSize * 0.113)
        .borderRadius(this.markSize * 0.03)
        .backgroundColor('#FFF9F0')
        .position({ x: this.markSize * 0.547, y: this.markSize * 0.398 })
        .opacity(this.blink ? 1 : 0)
    }
    .width(this.markSize)
    .height(this.markSize)
    .opacity(this.state === 'error' ? 0.65 : (this.pulse ? 0.88 : 1))
    .scale({
      x: this.cheer || this.state === 'happy' ? 1.06 : 1,
      y: this.cheer || this.state === 'happy' ? 1.06 : 1
    })
    .rotate({ angle: this.state === 'acting' ? -4 : 0 })
    .offset({
      y: this.state === 'idle' || this.state === 'waiting'
        ? (this.bob ? this.markSize * 0.025 : -this.markSize * 0.025)
        : 0
    })
    .animation({ duration: 900, curve: Curve.EaseInOut })
    .onClick(() => {
      Haptics.tap();
      this.wave();
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
