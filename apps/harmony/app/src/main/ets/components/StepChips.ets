/**
 * The per-step evidence under an answer: `✓ Opened Settings`, `✕ Tapped`.
 *
 * Shared so the phone and the laptop show the same record of what happened,
 * including failures, which are never hidden by the component itself.
 */
@Component
export struct StepChips {
  @Prop steps: string[] = [];
  @Prop dense: boolean = false;

  private tint(step: string): ResourceColor {
    if (step.startsWith('\u2715')) {
      return $r('app.color.warning');
    }
    if (step.startsWith('\u2713')) {
      return $r('app.color.success');
    }
    return $r('app.color.text_hint');
  }

  private label(step: string): string {
    return step.length > 2 ? step.substring(2) : step;
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      ForEach(this.steps, (step: string) => {
        Row({ space: 5 }) {
          Circle({ width: 4, height: 4 })
            .fill(this.tint(step))
          Text(this.label(step))
            .fontSize(this.dense ? 10.5 : 11)
            .fontColor($r('app.color.text_secondary'))
        }
        .padding({ left: 8, right: 9, top: 3, bottom: 3 })
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius(9)
        .margin({ right: 6, bottom: 4 })
      }, (step: string, index: number) => `${index}-${step}`)
    }
    .width('100%')
  }
}
