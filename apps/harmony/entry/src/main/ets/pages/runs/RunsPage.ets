import { BatchItemResult, RunRecord, Skill } from '@hopa/core';
import { Context } from '@kit.AbilityKit';
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
  private timer: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.timer = setInterval(() => {
      this.refresh();
    }, 2000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
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
        .fontColor('#999999')
        .width(100)
      Text(value)
        .fontSize(13)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  Detail() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('Back')
          .fontSize(12)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
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
            .fontColor(run.status === 'executed' ? '#0A7F3F' : '#B42318')
          Divider()
          this.TimelineRow('Started', new Date(run.startedAt).toLocaleTimeString())
          this.TimelineRow('Finished', new Date(run.finishedAt).toLocaleTimeString())
          this.TimelineRow('Duration', `${run.durationMs} ms`)
          this.TimelineRow('Approval', run.approved ? 'approved' : 'not required')
          this.TimelineRow('Payment', run.isPayment ? 'yes' : 'no')
          Divider()
          Text(run.detail.length > 0 ? run.detail : '(no detail)')
            .fontSize(13)
            .fontColor('#666666')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#F7F8FA')
        .borderRadius(10)
        .alignItems(HorizontalAlign.Start)
      }, (run: RunRecord, index: number) => run.id)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.selectedId.length > 0) {
      this.Detail()
    } else {
      Column({ space: 12 }) {
        Text('Runs and batches')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
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
          .fontColor('#666666')
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
              .backgroundColor('#B42318')
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
                  .fontColor('#999999')
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F7F8FA')
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
            .fontColor('#666666')
            .layoutWeight(1)
          if (this.runs.length > 0) {
            Button('Clear')
              .fontSize(11)
              .height(26)
              .backgroundColor('#E5E6E8')
              .fontColor('#B42318')
              .onClick(() => {
                this.clear();
              })
          }
        }
        .width('100%')
        Text(`Last run: ${AgentService.get().getLastTokens()} tokens | ${(AgentService.get().getLastDurationMs() / 1000).toFixed(1)} s`)
          .fontSize(11)
          .fontColor('#999999')
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
            .backgroundColor('#E5E6E8')
            .fontColor('#333333')
            .onClick(() => {
              this.resume();
            })
        }
        List({ space: 8 }) {
          ForEach(this.runs, (run: RunRecord, index: number) => {
            ListItem() {
              Column({ space: 2 }) {
                Row({ space: 8 }) {
                  Text(run.kind)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .layoutWeight(1)
                  Text(run.status)
                    .fontSize(12)
                    .fontColor(run.status === 'executed' ? '#0A7F3F' : '#B42318')
                }
                .width('100%')
                Text(run.detail.length > 0 ? run.detail : '(no detail)')
                  .fontSize(12)
                  .fontColor('#666666')
                  .maxLines(2)
                Text(`${run.durationMs} ms | ${run.approved ? 'approved' : 'no approval'} | ${run.isPayment ? 'payment' : 'normal'}`)
                  .fontSize(10)
                  .fontColor('#999999')
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F7F8FA')
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
      .padding(16)
      .alignItems(HorizontalAlign.Start)
    }
  }
}
