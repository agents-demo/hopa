import { ScheduledTask } from '@hopa/core';
import { AgentService } from '../../services/AgentService';

/**
 * Plans: in-app schedules that fire while the process is alive.
 * The HarmonyOS reminder agent rejects this emulator, so this is not a system
 * alarm and the copy says so.
 */
@Component
export struct PlansPage {
  @State goal: string = '';
  @State items: ScheduledTask[] = [];
  @State status: string = 'Idle';
  @State suggestions: string[] = [];
  private timer: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.timer = setInterval(() => {
      this.refresh();
    }, 5000);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private refresh(): void {
    this.items = AgentService.get().scheduleService.book.all().slice();
    this.suggestions = this.detect();
    if (AgentService.get().isBusy()) {
      this.status = 'Scheduled goal running';
    } else if (this.status === 'Scheduled goal running') {
      this.status = 'Idle';
    }
  }

  /** Goals the user has asked more than once and has not planned yet. */
  private detect(): string[] {
    const goals: string[] = [];
    const counts: number[] = [];
    for (const session of AgentService.get().conversations.all()) {
      for (const entry of session.entries) {
        if (entry.role !== 'user') {
          continue;
        }
        const goal: string = entry.text.trim();
        if (goal.length < 4 || goal.length > 90) {
          continue;
        }
        let found: number = -1;
        for (let i = 0; i < goals.length; i++) {
          if (goals[i].toLowerCase() === goal.toLowerCase()) {
            found = i;
            break;
          }
        }
        if (found >= 0) {
          counts[found] += 1;
        } else {
          goals.push(goal);
          counts.push(1);
        }
      }
    }
    const result: string[] = [];
    for (let i = 0; i < goals.length; i++) {
      if (counts[i] < 2) {
        continue;
      }
      let planned: boolean = false;
      for (const item of this.items) {
        if (item.goal.toLowerCase() === goals[i].toLowerCase()) {
          planned = true;
          break;
        }
      }
      if (!planned) {
        result.push(goals[i]);
      }
      if (result.length >= 3) {
        break;
      }
    }
    return result;
  }

  /** One tap turns a repeated goal into a daily 9:00 routine. */
  private async makeRoutine(goal: string): Promise<void> {
    const now: Date = new Date();
    const next: Date = new Date();
    next.setHours(9, 0, 0, 0);
    if (next.getTime() <= now.getTime()) {
      next.setDate(next.getDate() + 1);
    }
    const ok: boolean = await AgentService.get().scheduleService.add(
      goal,
      86400000,
      next.getTime() - now.getTime()
    );
    this.status = ok ? 'Routine added for 9:00' : 'Could not add the routine';
    this.refresh();
  }

  private async add(intervalMs: number, delayMs: number): Promise<void> {
    const ok: boolean = await AgentService.get().scheduleService.add(this.goal, intervalMs, delayMs);
    if (!ok) {
      this.status = 'Enter a goal for the plan';
      return;
    }
    this.goal = '';
    this.status = 'Plan added';
    this.refresh();
  }

  private async remove(id: string): Promise<void> {
    await AgentService.get().scheduleService.remove(id);
    this.refresh();
  }

  private when(item: ScheduledTask): string {
    if (!item.enabled) {
      return 'done';
    }
    const delta: number = item.nextRunAt - Date.now();
    if (delta <= 0) {
      return 'due now';
    }
    const minutes: number = Math.ceil(delta / 60000);
    return minutes <= 1 ? 'in <1 min' : `in ${minutes} min`;
  }

  build() {
    Column({ space: 12 }) {
      Text('Scheduled goals that run while HOPA is open. This image has no system alarm, so nothing fires after the app is closed.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text(this.status)
        .fontSize(12)
        .fontColor($r('app.color.text_hint'))
      if (this.suggestions.length > 0) {
        Text('SUGGESTED ROUTINES')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.6)
          .padding({ top: 4 })
        Column({ space: 6 }) {
          ForEach(this.suggestions, (goal: string) => {
            Row({ space: 8 }) {
              Text(goal)
                .fontSize(12.5)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('Daily at 9:00')
                .fontSize(10.5)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_primary'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor($r('app.color.primary'))
                .borderRadius(9)
                .onClick(() => {
                  this.makeRoutine(goal);
                })
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(10)
            .alignItems(VerticalAlign.Center)
          }, (goal: string) => goal)
        }
        .width('100%')
        Text('You have asked these more than once. A routine still passes the same approval gate.')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }

      Row({ space: 6 }) {
        Button('Every 5 min')
          .fontSize(10)
          .height(28)
          .onClick(() => {
            this.add(300000, 300000);
          })
        Button('Every 30 min')
          .fontSize(10)
          .height(28)
          .onClick(() => {
            this.add(1800000, 1800000);
          })
        Button('Daily')
          .fontSize(10)
          .height(28)
          .onClick(() => {
            this.add(86400000, 86400000);
          })
      }
      .width('100%')
      Row({ space: 6 }) {
        Button('Once in 1 min')
          .fontSize(10)
          .height(28)
          .onClick(() => {
            this.add(0, 60000);
          })
        Text(`${this.items.length} planned`)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      TextInput({ placeholder: 'Goal for the plan', text: this.goal })
        .fontSize(13)
        .onChange((value: string) => {
          this.goal = value;
        })
      if (this.items.length > 0) {
        List({ space: 4 }) {
          ForEach(this.items, (item: ScheduledTask, index: number) => {
            ListItem() {
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(item.goal)
                    .fontSize(13)
                    .maxLines(2)
                  Text(`${item.label()} | ${this.when(item)}`)
                    .fontSize(10)
                    .fontColor($r('app.color.text_hint'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('Delete')
                  .fontSize(10)
                  .height(26)
                  .backgroundColor($r('app.color.divider'))
                  .fontColor($r('app.color.danger'))
                  .onClick(() => {
                    this.remove(item.id);
                  })
              }
              .width('100%')
              .padding(8)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(8)
            }
          }, (item: ScheduledTask, index: number) => `${item.id}-${item.enabled}-${item.nextRunAt}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      } else {
        Text('No plans yet. Type a goal above, then choose how often it should run.')
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
