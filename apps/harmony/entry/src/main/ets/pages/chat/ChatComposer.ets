/** The chat composer: one rounded field and a send/stop/voice button. */
@Component
export struct ChatComposer {
  @Prop draft: string = '';
  @Prop busy: boolean = false;
  @Prop @Watch('onRecordingChange') recording: boolean = false;
  onDraft: (value: string) => void = () => {};
  onSend: () => void = () => {};
  onStop: () => void = () => {};
  onVoiceStart: () => void = () => {};
  onVoiceStop: () => void = () => {};
  @State pulse: boolean = false;
  /** Set from the wallpaper at startup; the brand colour is the fallback. */
  @StorageLink('hopa.accent') accentColor: string = '';
  private pulseTimer: number = -1;

  private canSend(): boolean {
    return this.draft.trim().length > 0;
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  /** Send and hand the screen back to the conversation, keyboard closed. */
  private submit(): void {
    this.onSend();
    this.getUIContext().getFocusController().clearFocus();
  }

  onRecordingChange(): void {
    if (this.recording) {
      if (this.pulseTimer < 0) {
        this.pulseTimer = setInterval(() => {
          this.pulse = !this.pulse;
        }, 620);
      }
    } else {
      if (this.pulseTimer >= 0) {
        clearInterval(this.pulseTimer);
        this.pulseTimer = -1;
      }
      this.pulse = false;
    }
  }

  aboutToDisappear(): void {
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
    }
  }

  /** A small hand-drawn microphone: capsule, stem and base. */
  @Builder
  MicGlyph(color: ResourceColor) {
    Column() {
      Column()
        .width(6)
        .height(10)
        .borderRadius(3)
        .backgroundColor(color)
      Column()
        .width(1.4)
        .height(3)
        .backgroundColor(color)
      Column()
        .width(8)
        .height(1.4)
        .borderRadius(1)
        .backgroundColor(color)
    }
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 4 }) {
        if (this.recording) {
          Row({ space: 6 }) {
            Circle({ width: 7, height: 7 })
              .fill($r('app.color.danger'))
              .opacity(this.pulse ? 1 : 0.35)
            Text('Listening — tap to stop')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .layoutWeight(1)
          .height(42)
          .padding({ left: 10 })
        } else {
          TextInput({ placeholder: 'Ask HOPA...', text: this.draft })
            .layoutWeight(1)
            .height(42)
            .fontSize(15)
            .backgroundColor(Color.Transparent)
            .padding({ left: 8, right: 2 })
            .onChange((value: string) => {
              this.onDraft(value);
            })
            .onSubmit(() => {
              this.submit();
            })
        }
        Stack({ alignContent: Alignment.Center }) {
          if (this.busy) {
            Column()
              .width(11)
              .height(11)
              .borderRadius(2)
              .backgroundColor($r('app.color.on_primary'))
          } else if (this.recording) {
            Column()
              .width(10)
              .height(10)
              .borderRadius(2)
              .backgroundColor($r('app.color.on_primary'))
          } else if (this.canSend()) {
            Text('↑')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
          } else {
            this.MicGlyph($r('app.color.text_secondary'))
          }
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.busy || this.recording
          ? $r('app.color.danger')
          : (this.canSend() ? this.accent() : $r('app.color.surface_muted')))
        .scale({ x: this.recording && this.pulse ? 1.08 : 1, y: this.recording && this.pulse ? 1.08 : 1 })
        .animation({ duration: 240, curve: Curve.EaseInOut })
        .accessibilityText(this.busy ? 'Stop' : (this.recording ? 'Stop listening' : (this.canSend() ? 'Send' : 'Speak')))
        .onClick(() => {
          if (this.busy) {
            this.onStop();
          } else if (this.recording) {
            this.onVoiceStop();
          } else if (this.canSend()) {
            this.submit();
          } else {
            this.onVoiceStart();
          }
        })
      }
      .width('100%')
      .padding({ left: 12, right: 4, top: 4, bottom: 4 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: this.recording ? '#66E4572E' : $r('app.color.divider') })
      .borderRadius(26)
    }
    .width('100%')
  }
}
