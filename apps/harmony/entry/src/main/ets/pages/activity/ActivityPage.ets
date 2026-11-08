import { AgentService } from '../../services/AgentService';

/** Activity: what HOPA is doing, what it did and what is scheduled. */
@Component
export struct ActivityPage {
  onNavigate: (key: string) => void = () => {};

  private isBusy(): boolean {
    return AgentService.get().isBusy();
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

  @Builder
  Card(title: string, subtitle: string, key: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
        Text(subtitle)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(17)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(12)
    .onClick(() => {
      this.onNavigate(key);
    })
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Column()
              .width(9)
              .height(9)
              .borderRadius(4.5)
              .backgroundColor(this.isBusy()
                ? $r('app.color.warning')
                : $r('app.color.success'))
            Text(this.isBusy() ? 'Working on something' : 'Ready')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
          }
          Text(this.tokens() > 0
            ? `Last run: ${this.tokens()} tokens · ${this.duration()} ms`
            : 'No run in this session.')
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
          Text(`${this.actions()} actions recorded`)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .alignItems(HorizontalAlign.Start)
        Text('RECENT')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .width('100%')
          .padding({ top: 6 })
        this.Card('Runs and batches', 'Every action, approval and duration', 'runs')
        this.Card('Screens', 'Live phone screen and tap targets', 'screens')
        Text('SCHEDULED')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .width('100%')
          .padding({ top: 6 })
        this.Card('Plans', 'Goals that run while HOPA is open', 'plans')
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: '100%' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
