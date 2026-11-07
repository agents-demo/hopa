import { AgentService } from '../../services/AgentService';

/** Counts, the last run's cost and the current stores. */
@Component
export struct UsagePage {
  private countRuns(status: string): number {
    let count: number = 0;
    for (const run of AgentService.get().runs.all()) {
      if (run.status === status) {
        count += 1;
      }
    }
    return count;
  }

  @Builder
  Line(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F7F8FA')
    .borderRadius(8)
  }

  build() {
    Column({ space: 10 }) {
      this.Line('Actions recorded', `${AgentService.get().runs.all().length}`)
      this.Line('Executed', `${this.countRuns('executed')}`)
      this.Line('Failed', `${this.countRuns('failed')}`)
      this.Line('Denied', `${this.countRuns('denied')}`)
      this.Line('Last run tokens', `${AgentService.get().getLastTokens()}`)
      this.Line('Last run time', `${(AgentService.get().getLastDurationMs() / 1000).toFixed(1)} s`)
      this.Line('Plans', `${AgentService.get().scheduleService.book.all().length}`)
      this.Line('Facts and skills', `${AgentService.get().memory.all().length} / ${AgentService.get().skills.all().length}`)
      Text('Per-run tokens are not stored yet; the last run total is shown.')
        .fontSize(11)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
