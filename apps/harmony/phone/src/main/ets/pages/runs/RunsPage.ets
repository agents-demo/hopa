import { BatchItemResult, RunRecord, Skill } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AgentService } from '../../services/AgentService';

/** Batch goals, the run history and one run's timeline. */
@Component
export struct RunsPage {
  @State batchText: string = '';
  @State batchResults: BatchItemResult[] = [];
  @State runs: RunRecord[] = [];
  @State status: string = 'Idle';
  @State busy: boolean = false;
  @State selectedId: string = '';
  @State filter: string = 'all';
  @State replaying: boolean = false;
  @State replayIndex: number = 0;
  @State replayRuns: RunRecord[] = [];
  private timer: number = -1;
  private replayTimer: number = -1;

  aboutToAppear(): void {
    this.refresh();
    const focus: string = AppStorage.get<string>('hopa.runsFocus') ?? '';
    if (focus.length > 0) {
      AppStorage.setOrCreate<string>('hopa.runsFocus', '');
      if (focus === 'replay') {
        setTimeout(() => {
          this.playReplay();
        }, 350);
      } else if (focus === 'batch') {
        this.status = 'Batch: one goal per line, then Run batch.';
      }
    }
    this.timer = setInterval(() => {
      this.refresh();
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.stopReplay();
  }

  /** Runs closer together than ten minutes belong to the same session. */
  private lastSession(): RunRecord[] {
    const all: RunRecord[] = this.runs;
    if (all.length === 0) {
      return [];
    }
    const session: RunRecord[] = [all[all.length - 1]];
    for (let index = all.length - 2; index >= 0; index--) {
      const gap: number = session[0].startedAt - all[index].finishedAt;
      if (gap > 10 * 60 * 1000) {
        break;
      }
      session.unshift(all[index]);
    }
    return session;
  }

  private playReplay(): void {
    if (this.replaying) {
      this.stopReplay();
      return;
    }
    const session: RunRecord[] = this.lastSession();
    if (session.length === 0) {
      this.status = 'No runs to replay yet';
      return;
    }
    this.replayRuns = session;
    this.replayIndex = session.length > 0 ? 1 : 0;
    this.replaying = true;
    this.replayTimer = setInterval(() => {
      if (this.replayIndex >= this.replayRuns.length) {
        this.stopReplay();
        return;
      }
      this.replayIndex += 1;
    }, 850);
  }

  private stopReplay(): void {
    if (this.replayTimer >= 0) {
      clearInterval(this.replayTimer);
      this.replayTimer = -1;
    }
    this.replaying = false;
  }

  private refresh(): void {
    this.runs = AgentService.get().runs.all().slice();
    this.busy = AgentService.get().isBusy();
  }

  private async runBatch(): Promise<void> {
    const goals: string[] = [];
    for (const line of this.batchText.split('\n')) {
      const goal: string = line.trim();
      if (goal.length > 0) {
        goals.push(goal);
      }
    }
    if (goals.length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.status = `Batch: ${goals.length} goals`;
    this.batchResults = await AgentService.get().runBatch(goals);
    this.busy = false;
    this.status = 'Idle';
    this.refresh();
  }

  private stop(): void {
    AgentService.get().cancel();
    this.status = 'Stopping...';
  }

  private async clear(): Promise<void> {
    AgentService.get().runs.clear();
    await AgentService.get().saveRuns(getContext(this) as Context);
    this.refresh();
    this.status = 'Cleared the run history';
  }

  private async draft(): Promise<void> {
    const skill: Skill | undefined = AgentService.get().saveLastRunAsSkill();
    if (skill !== undefined) {
      await AgentService.get().skills.save(getContext(this) as Context);
      this.status = `Saved "${skill.name}" as a skill`;
    }
  }

  private async resume(): Promise<void> {
    const reply: string = await AgentService.get().continueLast();
    this.status = reply.length > 80 ? reply.substring(0, 80) : reply;
    this.refresh();
  }

  private shownRuns(): RunRecord[] {
    if (this.filter === 'payments') {
      return this.runs.filter((run: RunRecord) => run.isPayment);
    }
    if (this.filter === 'failed') {
      return this.runs.filter((run: RunRecord) => run.status !== 'executed');
    }
    return this.runs;
  }

  @Builder
  FilterChip(label: string, key: string) {
    Text(label)
      .fontSize(11)
      .fontColor(this.filter === key ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
      .backgroundColor(this.filter === key ? $r('app.color.primary') : $r('app.color.surface_alt'))
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(9)
      .onClick(() => {
        this.filter = key;
      })
  }

  private selectedRuns(): RunRecord[] {
    const found: RunRecord[] = [];
    for (const run of this.runs) {
      if (run.id === this.selectedId) {
        found.push(run);
      }
    }
    return found;
  }

  @Builder
  TimelineRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
        .width(100)
      Text(value)
        .fontSize(13)
        .layoutWeight(1)
    }
    .width('100%')
  }

  private hasShots(): boolean {
    for (const run of this.replayRuns) {
      if (run.shot.length > 0) {
        return true;
      }
    }
    for (const run of this.lastSession()) {
      if (run.shot.length > 0) {
        return true;
      }
    }
    return false;
  }

  @Builder
  Replay() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('Session replay')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
          Text(`${this.lastSession().length} actions from the last session`)
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Button(this.replaying ? 'Stop' : 'Play')
          .fontSize(12)
          .height(28)
          .backgroundColor(this.replaying ? $r('app.color.danger') : $r('app.color.primary'))
          .onClick(() => {
            this.playReplay();
          })
      }
      .width('100%')
      if (this.hasShots()) {
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.replayRuns.length > 0 ? this.replayRuns : this.lastSession(),
              (run: RunRecord, index: number) => {
                if (run.shot.length > 0) {
                  Image('file://' + run.shot)
                    .width(46)
                    .height(82)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(6)
                    .border({
                      width: this.replayRuns.length > 0 && index < this.replayIndex ? 2 : 1,
                      color: this.replayRuns.length > 0 && index < this.replayIndex
                        ? $r('app.color.primary')
                        : $r('app.color.divider')
                    })
                    .onClick(() => {
                      if (this.replayRuns.length > 0) {
                        this.replayIndex = index + 1;
                      }
                    })
                }
              }, (run: RunRecord) => `film-${run.id}`)
          }
          .padding({ top: 2, bottom: 2 })
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
      ForEach(this.replayRuns.slice(0, this.replayIndex), (run: RunRecord, index: number) => {
        Row({ space: 8 }) {
          Text(`${index + 1}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary'))
            .width(18)
            .height(18)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.primary_soft'))
            .borderRadius(9)
          Column({ space: 1 }) {
            Text(run.kind)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
            Text(run.detail.length > 0 ? run.detail : '(no detail)')
              .fontSize(10.5)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text(`${Math.round((run.startedAt - this.replayRuns[0].startedAt) / 1000)}s`)
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding(8)
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius(8)
      }, (run: RunRecord) => `replay-${run.id}`)
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  /** One plain-text summary that can leave the app as it is. */
  private receiptText(run: RunRecord): string {
    const when: string = `${new Date(run.startedAt).toLocaleDateString()} ` +
      `${new Date(run.startedAt).toLocaleTimeString()}`;
    const outcome: string = run.status === 'executed' ? 'Done' : `${run.status}`;
    return `HOPA receipt\n` +
      `${outcome}: ${run.kind}\n` +
      `When: ${when}\n` +
      `Took: ${run.durationMs} ms\n` +
      `Approval: ${run.approved ? 'you approved' : 'not needed'}\n` +
      `Payment: ${run.isPayment ? 'yes' : 'no'}\n` +
      `Detail: ${run.detail.length > 0 ? run.detail : '(none)'}`;
  }

  private copyReceipt(run: RunRecord): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.receiptText(run));
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.status = 'Receipt copied';
      }).catch(() => {
        this.status = 'Could not copy the receipt';
      });
    } catch (error) {
      this.status = 'Could not copy the receipt';
    }
  }

  @Builder
  Receipt(run: RunRecord) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text('RECEIPT')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .layoutWeight(1)
        Text('Copy')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            this.copyReceipt(run);
          })
      }
      .width('100%')
      Text(this.receiptText(run))
        .fontSize(11)
        .lineHeight(17)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  Detail() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('Back')
          .fontSize(12)
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.selectedId = '';
          })
        Text('Run')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      ForEach(this.selectedRuns(), (run: RunRecord, index: number) => {
        Column({ space: 10 }) {
          Text(run.kind)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Text(run.status)
            .fontSize(13)
            .fontColor(run.status === 'executed' ? $r('app.color.success') : $r('app.color.danger'))
          if (run.shot.length > 0) {
            Image('file://' + run.shot)
              .width(82)
              .height(150)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .border({ width: 1, color: $r('app.color.divider') })
          }
          Divider()
          this.TimelineRow('Started', new Date(run.startedAt).toLocaleTimeString())
          this.TimelineRow('Finished', new Date(run.finishedAt).toLocaleTimeString())
          this.TimelineRow('Duration', `${run.durationMs} ms`)
          this.TimelineRow('Approval', run.approved ? 'approved' : 'not required')
          this.TimelineRow('Payment', run.isPayment ? 'yes' : 'no')
          Divider()
          this.Receipt(run)
          Text(run.detail.length > 0 ? run.detail : '(no detail)')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius(10)
        .alignItems(HorizontalAlign.Start)
      }, (run: RunRecord, index: number) => run.id)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.selectedId.length > 0) {
      this.Detail()
    } else {
      Column({ space: 12 }) {
        Text(this.status)
          .fontSize(16)
        if (this.busy) {
          Progress({ value: 50, total: 100, type: ProgressType.Linear })
            .width('100%')
        }
        Text(AgentService.get().isAccessibilityAvailable()
          ? 'Accessibility is available. The loop can read other apps.'
          : (AgentService.get().isBridgeConfigured()
            ? 'Accessibility is unavailable; actions go through the connected PC bridge.'
            : 'Accessibility is unavailable, so the loop can read only the built-in browser.'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text('Batch')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        TextArea({ placeholder: 'One goal per line', text: this.batchText })
          .height(80)
          .onChange((value: string) => {
            this.batchText = value;
          })
        Row({ space: 8 }) {
          Button('Run batch')
            .fontSize(12)
            .onClick(() => {
              this.runBatch();
            })
          if (this.busy) {
            Button('Stop')
              .fontSize(12)
              .backgroundColor($r('app.color.danger'))
              .onClick(() => {
                this.stop();
              })
          }
        }
        .width('100%')
        List({ space: 6 }) {
          ForEach(this.batchResults, (item: BatchItemResult, index: number) => {
            ListItem() {
              Column({ space: 2 }) {
                Text(item.goal)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                Text(item.output)
                  .fontSize(11)
                  .maxLines(3)
                Text(`${Math.round(item.durationMs / 1000)}s`)
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
              .padding(8)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(6)
              .alignItems(HorizontalAlign.Start)
            }
          }, (item: BatchItemResult, index: number) => `${index}-${item.goal}`)
        }
        .height(120)
        .width('100%')
        Row({ space: 8 }) {
          Text(`Recent actions (${this.runs.length})`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
          if (this.runs.length > 0) {
            Button('Clear')
              .fontSize(11)
              .height(26)
              .backgroundColor($r('app.color.divider'))
              .fontColor($r('app.color.danger'))
              .onClick(() => {
                this.clear();
              })
          }
        }
        .width('100%')
        Text(`Last run: ${AgentService.get().getLastTokens()} tokens | ${(AgentService.get().getLastDurationMs() / 1000).toFixed(1)} s`)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
        if (AgentService.get().canDraftSkill()) {
          Button('Save last run as skill')
            .fontSize(12)
            .height(30)
            .onClick(() => {
              this.draft();
            })
        }
        if (AgentService.get().canContinue()) {
          Button('Continue last task')
            .fontSize(12)
            .height(30)
            .backgroundColor($r('app.color.divider'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              this.resume();
            })
        }
        this.Replay()
        Row({ space: 6 }) {
          this.FilterChip('All', 'all')
          this.FilterChip('Payments', 'payments')
          this.FilterChip('Failed', 'failed')
        }
        .width('100%')
        List({ space: 8 }) {
          ForEach(this.shownRuns(), (run: RunRecord, index: number) => {
            ListItem() {
              Column({ space: 2 }) {
                Row({ space: 8 }) {
                  Text(run.kind)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                  Text(run.status)
                    .fontSize(12)
                    .fontColor(run.status === 'executed' ? $r('app.color.success') : $r('app.color.danger'))
                }
                .width('100%')
                Text(run.detail.length > 0 ? run.detail : '(no detail)')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(2)
                Text(`${run.durationMs} ms | ${run.approved ? 'approved' : 'no approval'} | ${run.isPayment ? 'payment' : 'normal'}`)
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.selectedId = run.id;
              })
            }
          }, (run: RunRecord) => run.id)
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
  }
}
