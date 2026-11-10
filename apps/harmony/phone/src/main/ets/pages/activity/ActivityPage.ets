import { RunRecord, RunStatus } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
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

  private lastGoal(): string {
    const service = AgentService.get();
    const live: string = service.runtime.lastGoalText();
    if (live.length > 0) {
      return live;
    }
    const sessions = service.conversations.all();
    let best: number = -1;
    let goal: string = '';
    for (let i = 0; i < sessions.length; i++) {
      const session = sessions[i];
      if (session.updatedAt < best) {
        continue;
      }
      for (let j = session.entries.length - 1; j >= 0; j--) {
        const entry = session.entries[j];
        if (entry.role === 'user' && entry.text.length > 0) {
          best = session.updatedAt;
          goal = entry.text;
          break;
        }
      }
    }
    return goal;
  }

  private weekRuns(): RunRecord[] {
    const cutoff: number = Date.now() - 7 * 24 * 60 * 60 * 1000;
    const week: RunRecord[] = [];
    for (const run of AgentService.get().runs.all()) {
      if (run.startedAt >= cutoff) {
        week.push(run);
      }
    }
    return week;
  }

  private weekDone(): number {
    let done: number = 0;
    for (const run of this.weekRuns()) {
      if (run.status === 'executed') {
        done += 1;
      }
    }
    return done;
  }

  private weekApps(): number {
    let apps: number = 0;
    for (const run of this.weekRuns()) {
      if (run.kind === 'ui.launch') {
        apps += 1;
      }
    }
    return apps;
  }

  private weekPayments(): number {
    let payments: number = 0;
    for (const run of this.weekRuns()) {
      if (run.isPayment) {
        payments += 1;
      }
    }
    return payments;
  }

  private weekRange(): string {
    const start = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    return `${start.toLocaleDateString()} - ${new Date().toLocaleDateString()}`;
  }

  private async shareWeek(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    try {
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 60);
      });
      const snapshot = await this.getUIContext().getComponentSnapshot().createFromBuilder(() => {
        this.WeekCard();
      });
      const packer: image.ImagePacker = image.createImagePacker();
      const png: ArrayBuffer = await packer.packing(snapshot, { format: 'image/png', quality: 92 });
      const path: string = `${context.cacheDir}/hopa-week-${Date.now()}.png`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(file.fd, png);
      } finally {
        fs.closeSync(file);
      }
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'image/png',
        uri: fileUri.getUriFromPath(path),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await context.startAbility(want);
    } catch (error) {
      this.getUIContext().getPromptAction().showToast({ message: 'Could not open the share sheet.' });
    }
  }

  private lastSteps(): string[] {
    return AgentService.get().runtime.lastSteps();
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
  WeekStat(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#14181F')
      Text(label)
        .fontSize(9)
        .fontColor('#8A9098')
        .letterSpacing(0.4)
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  WeekCard() {
    Column({ space: 10 }) {
      Text('HOPA \u00b7 WEEK IN REVIEW')
        .fontSize(9)
        .fontColor('#5B6470')
        .letterSpacing(0.8)
      Text(`${this.weekDone()} done`)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#14181F')
      Row({ space: 22 }) {
        this.WeekStat('ACTIONS', `${this.weekRuns().length}`)
        this.WeekStat('APPS', `${this.weekApps()}`)
        this.WeekStat('PAYMENTS', `${this.weekPayments()}`)
      }
      Text(this.weekRange())
        .fontSize(9)
        .fontColor('#8A9098')
      Text('Only what you choose leaves this phone.')
        .fontSize(9)
        .fontColor('#8A9098')
    }
    .width(320)
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
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
            HopaMark({ state: this.isBusy() ? 'acting' : 'idle', markSize: 34, interactive: false })
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
        if (this.lastGoal().length > 0) {
          Text('LAST RUN')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.6)
            .width('100%')
            .padding({ top: 6 })
          Column({ space: 8 }) {
            Text(this.lastGoal())
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            if (this.lastSteps().length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.lastSteps(), (step: string) => {
                  Text(step)
                    .fontSize(10.5)
                    .fontColor($r('app.color.text_secondary'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor($r('app.color.surface_alt'))
                    .borderRadius(8)
                    .margin({ right: 6, bottom: 4 })
                }, (step: string, i: number) => `${i}-${step}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)
        }
        Text('WEEK')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .width('100%')
          .padding({ top: 6 })
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('Week in review')
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
            Text(`${this.weekRuns().length} actions \u00b7 ${this.weekDone()} done \u00b7 ${this.weekApps()} apps`)
              .fontSize(10.5)
              .fontColor($r('app.color.text_hint'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Text('Share')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor($r('app.color.primary_soft'))
            .borderRadius(9)
            .onClick(() => {
              this.shareWeek();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(12)

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
