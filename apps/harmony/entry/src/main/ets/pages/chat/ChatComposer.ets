/** The chat composer: one rounded field and a send/stop button. */
@Component
export struct ChatComposer {
  @Prop draft: string = '';
  @Prop busy: boolean = false;
  onDraft: (value: string) => void = () => {};
  onSend: () => void = () => {};
  onStop: () => void = () => {};

  private canSend(): boolean {
    return this.draft.trim().length > 0;
  }

  /** Send and hand the screen back to the conversation, keyboard closed. */
  private submit(): void {
    this.onSend();
    this.getUIContext().getFocusController().clearFocus();
  }

  @Builder
  Chip(label: string, text: string) {
    Text(label)
      .fontSize(11)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(9)
      .onClick(() => {
        this.onDraft(text);
      })
  }

  build() {
    Column({ space: 6 }) {
      if (!this.busy && this.draft.trim().length === 0) {
        Row({ space: 6 }) {
          this.Chip('Bilibili top 3', 'Open Bilibili and show me the 3 most popular videos')
          this.Chip('Post to Weibo', "Post 'Hello world' on Weibo. Ask me first.")
        }
        .width('100%')
        .padding({ left: 10, right: 10 })
      }
    Row({ space: 4 }) {
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
      Stack({ alignContent: Alignment.Center }) {
        if (this.busy) {
          Column()
            .width(11)
            .height(11)
            .borderRadius(2)
            .backgroundColor($r('app.color.on_primary'))
        } else {
          Text('↑')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.canSend()
              ? $r('app.color.on_primary')
              : $r('app.color.text_hint'))
        }
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.busy
        ? $r('app.color.danger')
        : (this.canSend() ? $r('app.color.primary') : $r('app.color.surface_muted')))
      .accessibilityText(this.busy ? 'Stop' : 'Send')
      .onClick(() => {
        if (this.busy) {
          this.onStop();
        } else {
          this.submit();
        }
      })
    }
    .width('100%')
    .padding({ left: 12, right: 4, top: 4, bottom: 4 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(26)
    }
    .width('100%')
  }
}
