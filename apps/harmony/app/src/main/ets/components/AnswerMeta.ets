/**
 * The verification line under an answer.
 *
 * Verification is derived from the stored steps, not from the last run in
 * memory: if the steps were recorded and none failed, the screen was checked.
 * That is why the line survives a restart.
 */
@Component
export struct AnswerMeta {
  @Prop steps: string[] = [];
  @Prop hasActions: boolean = false;

  private verified(): boolean {
    if (!this.hasActions || this.steps.length === 0) {
      return false;
    }
    for (const step of this.steps) {
      if (step.startsWith('\u2715')) {
        return false;
      }
    }
    return true;
  }

  build() {
    if (this.hasActions && this.steps.length > 0) {
      Row({ space: 5 }) {
        Circle({ width: 5, height: 5 })
          .fill(this.verified() ? $r('app.color.success') : $r('app.color.warning'))
        Text(this.verified() ? 'Verified on screen' : 'Not verified on screen')
          .fontSize(9.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding({ left: 2, top: 1, bottom: 2 })
    }
  }
}
