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
    this.items = AgentService.get().schedules.all().slice();
    if (AgentService.get().isBusy()) {
      this.status = 'Scheduled goal running';
    } else if (this.status === 'Scheduled goal running') {
      this.status = 'Idle';
    }
  }

  private async add(intervalMs: number, delayMs: number): Promise<void> {
    const ok: boolean = await AgentService.get().addSchedule(this.goal, intervalMs, delayMs);
    if (!ok) {
      this.status = 'Enter a goal for the plan';
      return;
    }
    this.goal = '';
    this.status = 'Plan added';
    this.refresh();
  }

  private async remove(id: string): Promise<void> {
    await AgentService.get().removeSchedule(id);
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
      Text('Plans')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('Scheduled goals that run while HOPA is open. This image has no system alarm, so nothing fires after the app is closed.')
        .fontSize(12)
        .fontColor('#666666')
      Text(this.status)
        .fontSize(12)
        .fontColor('#999999')
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
          .fontColor('#999999')
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
                    .fontColor('#999999')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Button('Delete')
                  .fontSize(10)
                  .height(26)
                  .backgroundColor('#E5E6E8')
                  .fontColor('#B42318')
                  .onClick(() => {
                    this.remove(item.id);
                  })
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F7F8FA')
              .borderRadius(8)
            }
          }, (item: ScheduledTask, index: number) => `${item.id}-${item.enabled}-${item.nextRunAt}`)
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Text('No plans yet. Type a goal above, then choose how often it should run.')
          .fontSize(12)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
