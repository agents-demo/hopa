import { AgentService } from '../../services/AgentService';
import { HopaMark } from '../chat/HopaMark';

/** Usage: what HOPA has actually done, kept across restarts. */
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

  private actions(): number {
    return AgentService.get().runs.all().length;
  }

  private tokens(): number {
    return AgentService.get().getLastTokens();
  }

  private duration(): number {
    return AgentService.get().getLastDurationMs();
  }

  private hasHistory(): boolean {
    return this.actions() > 0 || this.tokens() > 0;
  }

  @Builder
  Section(label: string) {
    Text(label)
      .fontSize(10)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.6)
      .width('100%')
      .padding({ top: 6 })
  }

  @Builder
  Line(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
  }

  @Builder
  Card() {
    Column({ space: 0 }) {
      this.Line('Actions recorded', `${this.actions()}`)
      Divider().color($r('app.color.divider'))
      this.Line('Executed', `${this.countRuns('executed')}`)
      Divider().color($r('app.color.divider'))
      this.Line('Failed', `${this.countRuns('failed')}`)
      Divider().color($r('app.color.divider'))
      this.Line('Denied', `${this.countRuns('denied')}`)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 2, bottom: 2 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(14)
  }

  build() {
    Scroll() {
      Column({ space: 4 }) {
        Row({ space: 12 }) {
          HopaMark({ state: 'idle', markSize: 44, interactive: false })
          Column({ space: 2 }) {
            Text('Usage')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('What HOPA has done on this phone.')
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 4, bottom: 10 })

        if (!this.hasHistory()) {
          Column({ space: 8 }) {
            Text('No runs yet')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text('Ask HOPA something in Chat. Actions, decisions and token counts will appear here.')
              .fontSize(12)
              .lineHeight(18)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)
        } else {
          this.Section('ACTIONS')
          this.Card()
          this.Section('LAST RUN')
          Column({ space: 0 }) {
            this.Line('Tokens', this.tokens() > 0 ? `${this.tokens()}` : 'not reported')
            Divider().color($r('app.color.divider'))
            this.Line('Time', this.duration() > 0
              ? `${(this.duration() / 1000).toFixed(1)} s`
              : 'not reported')
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          this.Section('ON THIS PHONE')
          Column({ space: 0 }) {
            this.Line('Plans', `${AgentService.get().scheduleService.book.all().length}`)
            Divider().color($r('app.color.divider'))
            this.Line('Facts and skills',
              `${AgentService.get().memory.all().length} / ${AgentService.get().skills.all().length}`)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          Text('History keeps the last 100 actions. Token and time totals come from the most recent run.')
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r('app.color.text_hint'))
            .padding({ top: 8 })
        }
      }
      .width('100%')
      .padding(20)
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
