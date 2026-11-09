import { RunRecord, RunStatus } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { HopaMark } from '../chat/HopaMark';

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

  private recentActions(): RunRecord[] {
    const all: RunRecord[] = AgentService.get().runs.all();
    const result: RunRecord[] = [];
    const start: number = Math.max(0, all.length - 3);
    for (let index = all.length - 1; index >= start; index--) {
      result.push(all[index]);
    }
    return result;
  }

  private actionLabel(kind: string): string {
    if (kind === 'web.navigate') {
      return 'Opened a page';
    }
    if (kind === 'web.read') {
      return 'Read a page';
    }
    if (kind === 'web.click') {
      return 'Clicked on a page';
    }
    if (kind === 'web.type') {
      return 'Typed on a page';
    }
    if (kind === 'ui.launch') {
      return 'Opened an app';
    }
    if (kind === 'ui.tap' || kind === 'ui.doubleTap' || kind === 'ui.longPress') {
      return 'Tapped the screen';
    }
    if (kind === 'ui.type') {
      return 'Typed on the phone';
    }
    if (kind === 'ui.scroll') {
      return 'Scrolled the screen';
    }
    if (kind === 'ui.back') {
      return 'Went back';
    }
    if (kind === 'ui.home') {
      return 'Went home';
    }
    if (kind.startsWith('sandbox.')) {
      return 'Ran a script';
    }
    if (kind.startsWith('system.')) {
      return 'System action';
    }
    return kind;
  }

  private statusColor(status: RunStatus): ResourceColor {
    if (status === RunStatus.Executed) {
      return $r('app.color.success');
    }
    if (status === RunStatus.Denied) {
      return $r('app.color.warning');
    }
    return $r('app.color.danger');
  }

  private actionCountLabel(): string {
    const count: number = this.actions();
    return `${count} ${count === 1 ? 'action' : 'actions'} recorded`;
  }

  private ago(ms: number): string {
    const diff: number = Date.now() - ms;
    if (diff < 60000) {
      return 'now';
    }
    if (diff < 3600000) {
      return `${Math.floor(diff / 60000)}m`;
    }
    if (diff < 86400000) {
      return `${Math.floor(diff / 3600000)}h`;
    }
    return `${Math.floor(diff / 86400000)}d`;
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
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(12)
    .onClick(() => {
      this.onNavigate(key);
    })
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Column({ space: 6 }) {
          Row({ space: 10 }) {
            HopaMark({ state: this.isBusy() ? 'acting' : 'idle', markSize: 34 })
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
                ? `Last run: ${this.tokens()} tokens · ${(this.duration() / 1000).toFixed(1)} s`
                : 'No run yet.')
                .fontSize(11)
                .fontColor($r('app.color.text_hint'))
              Text(this.actionCountLabel())
                .fontSize(11)
                .fontColor($r('app.color.text_hint'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(14)
        .alignItems(HorizontalAlign.Start)
        if (this.recentActions().length > 0) {
          Text('RECENT ACTIONS')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.6)
            .width('100%')
            .padding({ top: 6 })
          Column({ space: 0 }) {
            ForEach(this.recentActions(), (record: RunRecord) => {
              Row({ space: 8 }) {
                Column()
                  .width(7)
                  .height(7)
                  .borderRadius(3.5)
                  .backgroundColor(this.statusColor(record.status))
                Text(this.actionLabel(record.kind))
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text(this.ago(record.startedAt))
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
              .height(38)
            }, (record: RunRecord) => record.id)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
        }
        Text('RECENT')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .width('100%')
          .padding({ top: 6 })
        this.Card('Runs and batches', 'Every action, approval and duration', 'runs')
        this.Card('Usage', 'Tokens and time spent', 'usage')
        Text('SCHEDULED')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .width('100%')
          .padding({ top: 6 })
        this.Card('Plans', 'Goals that run while HOPA is open', 'plans')
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: '100%' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
