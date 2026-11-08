/**
 * The HOPA mark: a warm, quiet companion that shows the agent's state.
 *
 * It is drawn from shapes, so it stays sharp at any density and needs no
 * assets. The coral accent is reserved for the agent; the rest of the app
 * stays warm paper plus blue actions.
 */
@Component
export struct HopaMark {
  @Prop state: string = 'idle';
  @Prop markSize: number = 32;
  @State pulse: boolean = false;
  private timer: number = -1;

  aboutToAppear(): void {
    if (this.state === 'thinking' || this.state === 'acting') {
      this.timer = setInterval(() => {
        this.pulse = !this.pulse;
      }, 520);
    }
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private eyeHeight(): number {
    if (this.state === 'waiting') {
      return this.markSize * 0.16;
    }
    if (this.state === 'thinking' || this.state === 'acting') {
      return this.markSize * 0.1;
    }
    if (this.state === 'error') {
      return this.markSize * 0.06;
    }
    return this.markSize * 0.13;
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
      Column()
        .width(this.markSize)
        .height(this.markSize)
        .borderRadius(this.markSize * 0.34)
        .backgroundColor($r('app.color.accent'))
      Row({ space: this.markSize * 0.16 }) {
        Column()
          .width(this.markSize * 0.09)
          .height(this.eyeHeight())
          .borderRadius(this.markSize * 0.045)
          .backgroundColor(Color.White)
        Column()
          .width(this.markSize * 0.09)
          .height(this.eyeHeight())
          .borderRadius(this.markSize * 0.045)
          .backgroundColor(Color.White)
      }
      .offset({ y: -this.markSize * 0.08 })
      Row()
        .width(this.markSize * (this.state === 'waiting' ? 0.26 : 0.2))
        .height(this.markSize * 0.035)
        .borderRadius(this.markSize * 0.02)
        .backgroundColor(Color.White)
        .opacity(this.state === 'error' ? 0.6 : 1)
        .offset({ y: this.markSize * 0.2 })
    }
    .width(this.markSize)
    .height(this.markSize)
    .opacity(this.state === 'error' ? 0.6 : (this.pulse ? 0.82 : 1))
    .animation({ duration: 450, curve: Curve.EaseInOut })
    .accessibilityText(this.label())
  }
}
