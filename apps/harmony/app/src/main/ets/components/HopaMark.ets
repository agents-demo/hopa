/**
 * HOPA, the living phone. The character is the same SVG used in the README
 * banner, so every shell and the artwork cannot drift apart.
 *
 * This copy lives in the shared app kit: the phone and the laptop render the
 * same mascot, and the tap feedback is supplied by the host (haptics on a
 * phone, nothing on a desktop).
 */
let tapFeedback: () => void = () => {};

/** A host that has haptics can register them here; others leave the default. */
export function setMascotTapFeedback(feedback: () => void): void {
  tapFeedback = feedback;
}

@Component
export struct HopaMark {
  @Prop state: string = 'idle';
  @Prop markSize: number = 32;
  /** Older transcript avatars stay still; only the live one breathes. */
  @Prop animate: boolean = true;
  /** The header mark is a status light, not a button. */
  @Prop interactive: boolean = true;
  /** 'phone' on the phone, 'laptop' on the 2in1: one character, two bodies. */
  @Prop body: string = 'phone';
  @State pulse: boolean = false;
  @State blink: boolean = false;
  @State cheer: boolean = false;
  @State bob: boolean = false;
  @State waveStep: number = 0;
  @State bubble: boolean = false;
  private timer: number = -1;
  private blinkTimer: number = -1;
  private cheerTimer: number = -1;
  private bobTimer: number = -1;
  private waveTimer: number = -1;
  private bubbleTimer: number = -1;

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
    if (this.bubbleTimer >= 0) {
      clearTimeout(this.bubbleTimer);
      this.bubbleTimer = -1;
    }
  }

  /** A short, warm greeting that appears beside the mascot, not a toast. */
  private speak(): void {
    if (this.bubbleTimer >= 0) {
      clearTimeout(this.bubbleTimer);
    }
    // Let the wave and the little cheer land first; the line follows.
    this.bubbleTimer = setTimeout(() => {
      this.bubble = true;
      this.bubbleTimer = setTimeout(() => {
        this.bubble = false;
        this.bubbleTimer = -1;
      }, 2200);
    }, 140);
  }

  /** The laptop lid is landscape, so its face and arm sit elsewhere. */
  private isLaptop(): boolean {
    return this.body === 'laptop';
  }

  private armX(): number {
    return this.markSize * (this.isLaptop() ? 0.838 : 0.713);
  }

  private armY(): number {
    return this.markSize * (this.isLaptop() ? 0.295 : 0.281);
  }

  private lidX(): number {
    return this.markSize * (this.isLaptop() ? 0.3945 : 0.414);
  }

  private lidRight(): number {
    return this.markSize * (this.isLaptop() ? 0.543 : 0.547);
  }

  private lidY(): number {
    return this.markSize * (this.isLaptop() ? 0.3125 : 0.398);
  }

  private lidWidth(): number {
    return this.markSize * (this.isLaptop() ? 0.0625 : 0.051);
  }

  private lidHeight(): number {
    return this.markSize * (this.isLaptop() ? 0.125 : 0.113);
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
    if (this.state === 'listening') {
      return 'HOPA is listening';
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
      Image(this.body === 'laptop'
        ? $r('app.media.hopa_body_laptop')
        : $r('app.media.hopa_body'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)

      // The arm is a separate layer so it can wave on tap.
      Column()
        .width(this.markSize * 0.062)
        .height(this.markSize * 0.20)
        .borderRadius(this.markSize * 0.031)
        .backgroundColor($r('app.color.accent'))
        .position({ x: this.armX(), y: this.armY() })
        .rotate({ angle: this.armAngle() })
        .animation({ duration: 110, curve: Curve.EaseInOut })

      // Closed eyelids: the same cream as the screen face in the SVG.
      Column()
        .width(this.lidWidth())
        .height(this.lidHeight())
        .borderRadius(this.markSize * 0.03)
        .backgroundColor('#FFF9F0')
        .position({ x: this.lidX(), y: this.lidY() })
        .opacity(this.blink ? 1 : 0)
      Column()
        .width(this.lidWidth())
        .height(this.lidHeight())
        .borderRadius(this.markSize * 0.03)
        .backgroundColor('#FFF9F0')
        .position({ x: this.lidRight(), y: this.lidY() })
        .opacity(this.blink ? 1 : 0)

      // The bubble only exists while it is shown: a hidden Text node would
      // still be picked up by observe and confuse the model.
      if (this.bubble && this.markSize >= 56) {
        Stack({ alignContent: Alignment.TopStart }) {
          Image($r('app.media.hopa_bubble_shadow'))
            .width(this.markSize * 1.70)
            .height(this.markSize * 0.99)
            .objectFit(ImageFit.Fill)
            .opacity(0.10)
            .offset({ x: this.markSize * 0.01, y: this.markSize * 0.05 })
          Image($r('app.media.hopa_bubble_shadow'))
            .width(this.markSize * 1.70)
            .height(this.markSize * 0.99)
            .objectFit(ImageFit.Fill)
            .opacity(0.06)
            .offset({ x: this.markSize * 0.02, y: this.markSize * 0.09 })
          Image($r('app.media.hopa_bubble'))
            .width(this.markSize * 1.70)
            .height(this.markSize * 0.99)
            .objectFit(ImageFit.Fill)
          Text("Hi, I'm HOPA 👋")
            .width(this.markSize * 1.70)
            .padding({ top: this.markSize * 0.20 })
            .textAlign(TextAlign.Center)
            .fontSize(this.markSize * 0.19)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .width(this.markSize * 1.70)
        .height(this.markSize * 0.99)
        .clip(false)
        .rotate({ angle: -3 })
        .position({
          x: this.markSize * 0.38,
          y: -this.markSize * 1.02
        })
        .transition(
          TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.86, y: 0.86 }))
        )
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.markSize)
    .height(this.markSize)
    .clip(false)
    .opacity(this.state === 'error' ? 0.65 : (this.pulse ? 0.88 : 1))
    .scale({
      x: this.cheer || this.state === 'happy' ? 1.06 : 1,
      y: this.cheer || this.state === 'happy' ? 1.06 : 1
    })
    .rotate({ angle: this.state === 'acting' ? -4 : (this.state === 'listening' ? -2 : 0) })
    .offset({
      y: this.state === 'idle' || this.state === 'waiting'
        ? (this.bob ? this.markSize * 0.025 : -this.markSize * 0.025)
        : 0
    })
    .animation({ duration: 900, curve: Curve.EaseInOut })
    .onClick(() => {
      if (!this.interactive) {
        return;
      }
      tapFeedback();
      this.wave();
      this.cheer = true;
      if (this.cheerTimer >= 0) {
        clearTimeout(this.cheerTimer);
      }
      this.cheerTimer = setTimeout(() => {
        this.cheer = false;
      }, 260);
      if (this.state !== 'thinking' && this.state !== 'acting') {
        this.speak();
      }
    })
    .accessibilityText(this.label())
  }
}
