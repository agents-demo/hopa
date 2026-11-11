import { RunRecord, RunStatus } from '@hopa/core';

/**
 * The right rail: the run behind the current answer, and the honest limits.
 *
 * It is a dumb component on purpose: the page owns the data, this owns the
 * layout, so neither drifts into the other.
 *
 * The pane carries only what the centre cannot already show — the steps, the
 * frame that was read, the measured cost, and the verbs. It never repeats the
 * conversation, and a section appears only when it has something true to say.
 */
@Component
export struct ChatRail {
  /** The local run records for the last question, oldest first. */
  @Prop runs: RunRecord[] = [];
  /** The answer's step chips, used when the run happened on the other device. */
  @Prop steps: string[] = [];
  /** The last frame read during the run, if one was captured. */
  @Prop shot: string = '';
  @Prop shotAt: number = 0;
  @Prop busy: boolean = false;
  @Prop lastLatency: number = 0;
  @Prop lastTokens: number = 0;
  /** True when a PC bridge is configured, so the screen is really readable. */
  @Prop bridgeLive: boolean = false;
  @Prop metrics: boolean = true;
  @Prop approvalOpen: boolean = false;
  @Prop approvalDetail: string = '';
  /** The last frame the bridge captured before this step: evidence, not decoration. */
  @Prop approvalFrame: string = '';
  @Prop canUndo: boolean = false;
  onCopy: () => void = () => {};
  onRetry: () => void = () => {};
  onUndo: () => void = () => {};
  onAllow: () => void = () => {};
  onDeny: () => void = () => {};

  @Builder
  Label(text: string) {
    Text(text)
      .fontSize(9)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.8)
      .width('100%')
  }

  @Builder
  Verb(label: string, action: () => void) {
    Text(label)
      .fontSize(11)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(9)
      .onClick(() => {
        action();
      })
  }

  private seconds(ms: number): string {
    if (ms >= 1000) {
      return `${(ms / 1000).toFixed(1)} s`;
    }
    return `${ms} ms`;
  }

  private clock(at: number): string {
    if (at <= 0) {
      return '';
    }
    const when = new Date(at);
    const hour = when.getHours();
    const minute = when.getMinutes();
    return `${hour < 10 ? '0' : ''}${hour}:${minute < 10 ? '0' : ''}${minute}`;
  }

  private dot(status: RunStatus): ResourceColor {
    if (status === RunStatus.Executed) {
      return $r('app.color.success');
    }
    if (status === RunStatus.Denied) {
      return $r('app.color.warning');
    }
    return $r('app.color.danger');
  }

  /** The verb is what HOPA tried; the detail is what happened. Two different facts. */
  private verb(run: RunRecord): string {
    if (run.kind === 'ui.launch') {
      return 'Open app';
    }
    if (run.kind === 'ui.tap' || run.kind === 'ui.doubleTap' || run.kind === 'ui.longPress') {
      return 'Tap';
    }
    if (run.kind === 'ui.type') {
      return 'Type';
    }
    if (run.kind === 'ui.back') {
      return 'Back';
    }
    if (run.kind === 'ui.home') {
      return 'Home';
    }
    if (run.kind === 'ui.swipe' || run.kind === 'ui.scroll') {
      return 'Swipe';
    }
    return run.kind;
  }

  private summary(): string {
    let ms: number = 0;
    let failed: number = 0;
    for (const run of this.runs) {
      ms += run.durationMs;
      if (run.status === RunStatus.Failed) {
        failed += 1;
      }
    }
    const count: number = this.runs.length;
    const steps: string = `${count} step${count === 1 ? '' : 's'}`;
    return failed > 0
      ? `${steps} \u00b7 ${this.seconds(ms)} \u00b7 ${failed} failed`
      : `${steps} \u00b7 ${this.seconds(ms)}`;
  }

  private chipLabel(step: string): string {
    return step.length > 2 ? step.substring(2) : step;
  }

  private chipTint(step: string): ResourceColor {
    if (step.startsWith('\u2715')) {
      return $r('app.color.danger');
    }
    if (step.startsWith('\u2713')) {
      return $r('app.color.success');
    }
    return $r('app.color.text_hint');
  }

  @Builder
  TraceRow(run: RunRecord) {
    Row({ space: 8 }) {
      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(this.dot(run.status))
        .margin({ top: 5 })
      Column({ space: 2 }) {
        Text(this.verb(run))
          .fontSize(11.5)
          .lineHeight(16)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (run.detail.length > 0) {
          Text(run.detail)
            .fontSize(10)
            .lineHeight(14)
            .fontColor($r('app.color.text_hint'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        } else if (run.changed.length > 0) {
          Text(run.changed)
            .fontSize(10)
            .lineHeight(14)
            .fontColor($r('app.color.text_hint'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column({ space: 1 }) {
        Text(this.seconds(run.durationMs))
          .fontSize(9.5)
          .fontColor($r('app.color.text_hint'))
        if (run.status !== RunStatus.Executed) {
          Text(run.status === RunStatus.Denied ? 'blocked' : 'failed')
            .fontSize(9)
            .fontColor(run.status === RunStatus.Denied
              ? $r('app.color.warning')
              : $r('app.color.danger'))
        }
      }
      .alignItems(HorizontalAlign.End)
      .margin({ top: 2 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ChipRow(step: string) {
    Row({ space: 8 }) {
      Row()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(this.chipTint(step))
        .margin({ top: 5 })
      Text(this.chipLabel(step))
        .fontSize(11.5)
        .lineHeight(16)
        .fontColor($r('app.color.text_secondary'))
        .decoration({
          type: step.startsWith('\u2715') ? TextDecorationType.LineThrough : TextDecorationType.None,
          color: $r('app.color.text_hint')
        })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        this.Verb('Copy', this.onCopy)
        if (!this.busy) {
          this.Verb('Retry', this.onRetry)
        }
        if (this.canUndo) {
          this.Verb('Undo', this.onUndo)
        }
        Blank()
      }
      .width('100%')
      .padding({ bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          if (this.approvalOpen) {
            Column({ space: 8 }) {
              this.Label('YOUR OK')
              if (this.approvalFrame.length > 0) {
                Column({ space: 4 }) {
                  this.Label('WHAT HOPA SAW')
                  Image(this.approvalFrame)
                    .width('100%')
                    .height(88)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(7)
                    .border({ width: 1, color: $r('app.color.divider') })
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
              Text(this.approvalDetail)
                .fontSize(12.5)
                .lineHeight(18)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
              Row({ space: 8 }) {
                Text('Not now')
                  .fontSize(11.5)
                  .fontColor($r('app.color.text_primary'))
                  .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                  .backgroundColor($r('app.color.surface_muted'))
                  .borderRadius(14)
                  .onClick(() => {
                    this.onDeny();
                  })
                Text('Allow')
                  .fontSize(11.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.on_primary'))
                  .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                  .backgroundColor($r('app.color.primary'))
                  .borderRadius(14)
                  .onClick(() => {
                    this.onAllow();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.primary_soft') })
            .alignItems(HorizontalAlign.Start)

            Divider().color($r('app.color.divider'))
          }

          if (this.runs.length > 0) {
            Column({ space: 8 }) {
              this.Label('WHAT HOPA DID')
              Text(this.summary())
                .fontSize(10.5)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
              ForEach(this.runs, (run: RunRecord) => {
                this.TraceRow(run)
              }, (run: RunRecord) => `${run.id}-${run.startedAt}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Divider().color($r('app.color.divider'))
          } else if (this.steps.length > 0) {
            Column({ space: 8 }) {
              this.Label('WHAT HOPA DID')
              Text('Recorded on the device that ran it.')
                .fontSize(10.5)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
              ForEach(this.steps, (step: string, index: number) => {
                this.ChipRow(step)
              }, (step: string, index: number) => `${index}-${step}`)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Divider().color($r('app.color.divider'))
          }

          if (this.shot.length > 0) {
            Column({ space: 6 }) {
              this.Label('WHAT HOPA SAW')
              Image(this.shot)
                .width('100%')
                .height(96)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
                .border({ width: 1, color: $r('app.color.divider') })
              Text(this.shotAt > 0 ? `Frame read at ${this.clock(this.shotAt)}.` : 'The frame HOPA read.')
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Divider().color($r('app.color.divider'))
          }

          // Facts the centre pane does not already show, and only when they
          // were actually measured. A synced answer simply has no timing.
          if (this.metrics && this.lastLatency > 0) {
            Column({ space: 6 }) {
              this.Label('THIS ANSWER')
              Text(`${(this.lastLatency / 1000).toFixed(1)} s  \u00b7  ${this.lastTokens} tokens`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)

      Divider().color($r('app.color.divider'))

      Column({ space: 6 }) {
        this.Label('WHAT HOPA SEES')
        Text(this.bridgeLive
          ? 'PC bridge connected. HOPA can read this screen when you ask, and every action asks first.'
          : 'PC bridge not connected. HOPA sees only this conversation; connect the bridge in Settings to let it read the screen.')
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .width('100%')
      .padding({ top: 10 })
      .alignItems(HorizontalAlign.Start)
    }
    .width(258)
    .height('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 14 })
    .backgroundColor($r('app.color.surface_alt'))
    .border({ width: { left: 1 }, color: $r('app.color.divider') })
    .alignItems(HorizontalAlign.Start)
  }
}
