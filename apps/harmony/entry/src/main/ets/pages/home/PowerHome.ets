import { RunRecord } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Millennial/power home: command bar, recent automations, batch and logs. */
@Component
export struct PowerHome {
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenRuns: () => void = () => {};
  @State command: string = '';
  @State tick: number = 0;
  @StorageLink('hopa.style') styleName: string = 'calm';
  @StorageLink('hopa.accent') accentColor: string = '';
  private ticker: number = -1;

  aboutToAppear(): void {
    this.ticker = setInterval(() => {
      this.tick = (this.tick + 1) % 10000;
    }, 1500);
  }

  aboutToDisappear(): void {
    if (this.ticker >= 0) {
      clearInterval(this.ticker);
      this.ticker = -1;
    }
  }

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  private accent(): ResourceColor {
    // Power stays on the brand palette; the wallpaper tint is playful-only.
    return $r('app.color.primary');
  }

  private recent(): RunRecord[] {
    const all: RunRecord[] = AgentService.get().runs.all();
    return all.slice(Math.max(0, all.length - 5)).reverse();
  }

  private run(): void {
    const goal: string = this.command.trim();
    if (goal.length === 0) {
      return;
    }
    this.command = '';
    this.onOpenChat(goal, false);
  }

  @Builder
  Action(label: string) {
    Text(label)
      .fontSize(11)
      .fontColor($r('app.color.text_secondary'))
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor($r('app.color.surface_alt'))
      .borderRadius(8)
      .onClick(() => {
        this.onOpenRuns();
      })
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        HopaMark({ state: 'idle', markSize: 22, interactive: false })
        Text('HOPA')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(AgentService.get().isBridgeConfigured() ? 'bridge on' : 'bridge off')
          .fontSize(10)
          .fontColor(AgentService.get().isBridgeConfigured()
            ? $r('app.color.success') : $r('app.color.text_hint'))
        Text(`${AgentService.get().getLastTokens()} tok`)
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('⌘')
          .fontSize(17)
          .fontColor(this.accent())
        TextInput({ placeholder: 'Ask, or type /batch /replay /logs', text: this.command })
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.command = value;
          })
          .onSubmit(() => {
            this.run();
          })
        Text('Run')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.accent())
          .borderRadius(9)
          .onClick(() => {
            this.run();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 6, top: 5, bottom: 5 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(12)

      Row({ space: 6 }) {
        this.Action('Batch')
        this.Action('Replay')
        this.Action('Logs')
        Blank()
        Text(`${AgentService.get().runs.all().length} runs`)
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      Text('RECENT AUTOMATIONS')
        .fontSize(9)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.6)
        .width('100%')

      if (this.recent().length === 0) {
        Text('No automations yet. Type a goal above.')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(10)
      } else {
        ForEach(this.recent(), (run: RunRecord) => {
          Row({ space: 8 }) {
            Circle({ width: 6, height: 6 })
              .fill(run.status === 'executed' ? $r('app.color.success') : $r('app.color.danger'))
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
            Text(`${run.durationMs} ms`)
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
          }
          .width('100%')
          .padding(10)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(9)
          .onClick(() => {
            this.onOpenRuns();
          })
        }, (run: RunRecord) => run.id)
      }
      Blank()
      Text('Tap a row for the receipt, replay and full logs.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
