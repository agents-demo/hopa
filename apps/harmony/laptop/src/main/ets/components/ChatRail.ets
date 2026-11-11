import { RunRecord, RunStatus } from '@hopa/core';

/**
 * One earlier run in this chat, shown as a compact row under the current run.
 * Declared here so the page and the rail share one type.
 */
export class RailHistory {
  label: string = '';
  at: number = 0;
  ok: boolean = true;

  constructor(label: string, at: number, ok: boolean) {
    this.label = label;
    this.at = at;
    this.ok = ok;
  }
}

/**
 * The right rail: the run behind the current answer.
 *
 * This is the one thing a chat cannot show — what HOPA did to this machine,
 * in order, with the frame it read at each step. It is a plain component on
 * purpose: the page owns the data, this owns the layout.
 *
 * The pane is only mounted when it has something to say (a run, a frame, a
 * measured answer, or a consent), so it never takes width to show a void.
 */
@Component
export struct ChatRail {
  /** The local run records for the last question, oldest first. */
  @Prop runs: RunRecord[] = [];
  /** The answer's step chips, used when the run happened on the other device. */
  @Prop steps: string[] = [];
  @Prop lastLatency: number = 0;
  @Prop lastTokens: number = 0;
  /** True when a PC bridge is configured, so the screen is really readable. */
  @Prop bridgeLive: boolean = false;
  @Prop metrics: boolean = true;
  /** The question behind a run that is not the last answer, or ''. */
  @Prop contextTitle: string = '';
  /** Other runs in this conversation, newest first. */
  @Prop history: RailHistory[] = [];
  @Prop busy: boolean = false;
  @Prop hasAnswer: boolean = false;
  @Prop approvalOpen: boolean = false;
  @Prop approvalDetail: string = '';
  /** The last frame the bridge captured before this step: evidence, not decoration. */
  @Prop approvalFrame: string = '';
  @Prop canUndo: boolean = false;
  onCopy: () => void = () => {};
  onRetry: () => void = () => {};
  onUndo: () => void = () => {};
  onOpenActivity: () => void = () => {};
  onAllow: () => void = () => {};
  onDeny: () => void = () => {};

  /** Which step's frame is showing; empty means the newest frame. */
  @State selected: string = '';

  @Builder
  Label(text: string) {
    Text(text)
      .fontSize(9)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.8)
  }

  @Builder
  Verb(label: string, action: () => void) {
    // Ghost verbs: the filled surface belongs to consent, not to a copy link.
    Text(label)
      .fontSize(10.5)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .borderRadius(6)
      .hoverEffect(HoverEffect.Highlight)
      .onClick(() => {
        action();
      })
  }

  private seconds(ms: number): string {
    return ms >= 1000 ? `${(ms / 1000).toFixed(1)} s` : `${ms} ms`;
  }

  private tokens(count: number): string {
    return count >= 1000 ? `${(count / 1000).toFixed(1)}k tokens` : `${count} tokens`;
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

  /** The verb is what HOPA tried; the detail is what happened. */
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

  private outcome(run: RunRecord): string {
    if (run.detail.length > 0) {
      return run.detail;
    }
    return run.changed;
  }

  private totalMs(): number {
    let ms: number = 0;
    for (const run of this.runs) {
      ms += run.durationMs;
    }
    return ms;
  }

  private firstFailure(): number {
    for (let i = 0; i < this.runs.length; i++) {
      if (this.runs[i].status !== RunStatus.Executed) {
        return i + 1;
      }
    }
    return 0;
  }

  private statusHead(): string {
    if (this.approvalOpen) {
      return 'Needs your OK';
    }
    if (this.busy) {
      return 'Working\u2026';
    }
    if (this.runs.length > 0) {
      return this.firstFailure() > 0 ? `Failed at step ${this.firstFailure()}` : 'Succeeded';
    }
    if (this.steps.length > 0) {
      return 'Ran on another device';
    }
    if (this.metrics && this.lastLatency > 0) {
      return 'Answered';
    }
    return '';
  }

  private statusFacts(): string {
    if (this.runs.length > 0) {
      const count: number = this.runs.length;
      return `${count === 1 ? '1 step' : `${count} steps`} \u00b7 ${this.seconds(this.totalMs())}`;
    }
    if (this.steps.length > 0) {
      const count: number = this.steps.length;
      return `${count === 1 ? '1 step' : `${count} steps`} \u00b7 no local record`;
    }
    if (this.metrics && this.lastLatency > 0) {
      return `${(this.lastLatency / 1000).toFixed(1)} s`;
    }
    return '';
  }

  private statusTint(): ResourceColor {
    if (this.approvalOpen) {
      return $r('app.color.warning');
    }
    if (this.busy) {
      return $r('app.color.primary');
    }
    if (this.runs.length > 0) {
      return this.firstFailure() > 0 ? $r('app.color.danger') : $r('app.color.success');
    }
    return $r('app.color.text_hint');
  }

  private title(): string {
    if (this.approvalOpen) {
      return 'YOUR OK';
    }
    if (this.runs.length > 0) {
      return this.contextTitle.length > 0 ? 'LAST RUN' : 'THIS RUN';
    }
    if (this.steps.length > 0 || this.busy) {
      return 'THIS RUN';
    }
    return 'THIS ANSWER';
  }

  /** The newest frame unless a step was picked, so evidence is never hidden. */
  private frameRun(): RunRecord | undefined {
    if (this.selected.length > 0) {
      for (const run of this.runs) {
        if (run.id === this.selected && run.shot.length > 0) {
          return run;
        }
      }
    }
    for (let i = this.runs.length - 1; i >= 0; i--) {
      if (this.runs[i].shot.length > 0) {
        return this.runs[i];
      }
    }
    return undefined;
  }

  private frameStep(run: RunRecord): number {
    for (let i = 0; i < this.runs.length; i++) {
      if (this.runs[i].id === run.id) {
        return i + 1;
      }
    }
    return 0;
  }

  private isFrame(run: RunRecord): boolean {
    const frame: RunRecord | undefined = this.frameRun();
    return frame !== undefined && frame.id === run.id;
  }

  private frameShot(): string {
    const frame: RunRecord | undefined = this.frameRun();
    return frame === undefined ? '' : frame.shot;
  }

  private frameAt(): number {
    const frame: RunRecord | undefined = this.frameRun();
    return frame === undefined ? 0 : frame.startedAt;
  }

  private frameStepNo(): number {
    const frame: RunRecord | undefined = this.frameRun();
    return frame === undefined ? 0 : this.frameStep(frame);
  }

  /** Bound the trace so the card stays a card; Activity has the full story. */
  private shownRuns(): RunRecord[] {
    return this.runs.length > 6 ? this.runs.slice(this.runs.length - 6) : this.runs;
  }

  @Builder
  StepRow(run: RunRecord, index: number) {
    Row({ space: 8 }) {
      Text(`${index + 1}`)
        .fontSize(9.5)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.dot(run.status))
        .borderRadius(9)
      Column({ space: 1 }) {
        Text(this.verb(run))
          .fontSize(11.5)
          .lineHeight(15)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.outcome(run).length > 0) {
          Text(this.outcome(run))
            .fontSize(10)
            .lineHeight(14)
            .fontColor($r('app.color.text_hint'))
            .maxLines(2)
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
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 5, bottom: 5 })
    .borderRadius(6)
    .backgroundColor(this.isFrame(run) ? $r('app.color.surface') : Color.Transparent)
    .onClick(() => {
      if (run.shot.length > 0) {
        this.selected = run.id;
      }
    })
  }

  @Builder
  ChipRow(step: string, index: number) {
    Row({ space: 8 }) {
      Text(`${index + 1}`)
        .fontSize(9.5)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
        .width(18)
        .height(18)
        .textAlign(TextAlign.Center)
        .backgroundColor(step.startsWith('\u2715') ? $r('app.color.danger') : $r('app.color.success'))
        .borderRadius(9)
      Text(step.length > 2 ? step.substring(2) : step)
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
    Column() {
      Row({ space: 6 }) {
        this.Label(this.title())
        Blank()
        if (!this.approvalOpen && !this.busy) {
          if (this.hasAnswer) {
            this.Verb('Copy', this.onCopy)
          }
          this.Verb('Retry', this.onRetry)
          if (this.canUndo) {
            this.Verb('Undo', this.onUndo)
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 3 }) {
        Row({ space: 7 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.statusTint())
          Text(this.statusHead())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .letterSpacing(-0.2)
            .maxLines(2)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        if (this.statusFacts().length > 0) {
          Text(this.statusFacts())
            .fontSize(10.5)
            .fontColor($r('app.color.text_hint'))
            .width('100%')
        }
        if (this.contextTitle.length > 0) {
          Text(`Earlier: ${this.contextTitle}`)
            .fontSize(10)
            .lineHeight(14)
            .fontColor($r('app.color.text_hint'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .width('100%')
      .padding({ top: 6, bottom: 4 })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 10 }) {
        if (this.approvalOpen) {
          Column({ space: 8 }) {
              if (this.approvalFrame.length > 0) {
                Column({ space: 4 }) {
                  this.Label('WHAT HOPA SAW')
                  Image(this.approvalFrame)
                    .width('100%')
                    .height(104)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
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
                  .fontSize(12)
                  .fontColor($r('app.color.text_primary'))
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .padding({ top: 9, bottom: 9 })
                  .backgroundColor($r('app.color.surface_muted'))
                  .borderRadius(10)
                  .onClick(() => {
                    this.onDeny();
                  })
                Text('Allow')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.on_primary'))
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .padding({ top: 9, bottom: 9 })
                  .backgroundColor($r('app.color.primary'))
                  .borderRadius(10)
                  .onClick(() => {
                    this.onAllow();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.primary_soft') })
            .alignItems(HorizontalAlign.Start)
          }

          if (!this.busy) {
          if (this.runs.length > 0) {
            Column({ space: 2 }) {
              ForEach(this.shownRuns(), (run: RunRecord, index: number) => {
                this.StepRow(run, index)
              }, (run: RunRecord) => `${run.id}-${run.startedAt}`)
            }
            .width('100%')
          } else if (this.steps.length > 0) {
            Column({ space: 6 }) {
              ForEach(this.steps, (step: string, index: number) => {
                this.ChipRow(step, index)
              }, (step: string, index: number) => `${index}-${step}`)
            }
            .width('100%')
          }

          if (this.frameShot().length > 0) {
            Column({ space: 4 }) {
              this.Label('WHAT HOPA SAW')
              Image(this.frameShot())
                .width('100%')
                .height(104)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
                .border({ width: 1, color: $r('app.color.divider') })
              Text(`Frame \u00b7 ${this.clock(this.frameAt())} \u00b7 step ${this.frameStepNo()}`)
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          if (this.history.length > 0) {
            Column({ space: 6 }) {
              Row({ space: 6 }) {
                this.Label('EARLIER IN THIS CHAT')
                Blank()
                Text('Activity')
                  .fontSize(9.5)
                  .fontColor($r('app.color.primary'))
                  .onClick(() => {
                    this.onOpenActivity();
                  })
              }
              .width('100%')
              ForEach(this.history, (row: RailHistory) => {
                Row({ space: 8 }) {
                  Row()
                    .width(6)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(row.ok ? $r('app.color.success') : $r('app.color.danger'))
                    .margin({ top: 4 })
                  Text(row.label.length > 0 ? row.label : 'Action')
                    .fontSize(10.5)
                    .lineHeight(15)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(this.clock(row.at))
                    .fontSize(9.5)
                    .fontColor($r('app.color.text_hint'))
                }
                .width('100%')
                .onClick(() => {
                  this.onOpenActivity();
                })
              }, (row: RailHistory) => `${row.at}-${row.label}`)
            }
            .width('100%')
            .padding({ top: 6 })
            .alignItems(HorizontalAlign.Start)
          }

          if (this.metrics && this.lastLatency > 0) {
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                this.Label('MEASURED')
                Blank()
                Text(`${(this.lastLatency / 1000).toFixed(1)} s  \u00b7  ${this.tokens(this.lastTokens)}`)
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 8 })
          }
          }
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      .padding({ top: 8 })

      Divider().color($r('app.color.divider'))

      Row({ space: 6 }) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.bridgeLive ? $r('app.color.success') : $r('app.color.warning'))
          .margin({ top: 4 })
        Text(this.bridgeLive
          ? 'Bridge connected \u00b7 every action asks first.'
          : 'No bridge \u00b7 HOPA sees only this conversation.')
          .fontSize(10)
          .lineHeight(14)
          .fontColor($r('app.color.text_hint'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 10 })
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(14)
    .alignItems(HorizontalAlign.Start)
    }
    .width(258)
    .height('100%')
    .padding({ left: 10, right: 10, top: 68, bottom: 12 })
    .backgroundColor(Color.Transparent)
    .alignItems(HorizontalAlign.Start)
  }
}
