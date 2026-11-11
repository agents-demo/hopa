import { RunRecord } from '@hopa/core';
import { pasteboard } from '@kit.BasicServicesKit';
import { AgentService } from '../../services/AgentService';
import { VisualStyle } from '../../services/VisualStyle';
import { HopaMark } from '../chat/HopaMark';

/** Gen Z home: a feed of what HOPA did, made to share. */
@Component
export struct SocialHome {
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenRuns: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'vivid';
  @StorageLink('hopa.accent') accentColor: string = '';
  @State selected: number = -1;
  @State showFailures: boolean = false;
  @State tick: number = 0;
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

  private style(): VisualStyle {
    return VisualStyle.of(this.styleName);
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private feed(): RunRecord[] {
    const all: RunRecord[] = AgentService.get().runs.all();
    const kept: RunRecord[] = [];
    for (const run of all) {
      if (this.showFailures || run.status === 'executed') {
        kept.push(run);
      }
    }
    return kept.slice(Math.max(0, kept.length - 6)).reverse();
  }

  private todayCount(): number {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    let count: number = 0;
    for (const run of AgentService.get().runs.all()) {
      if (run.startedAt >= start.getTime()) {
        count += 1;
      }
    }
    return count;
  }

  private weekCount(): number {
    const cutoff: number = Date.now() - 7 * 24 * 60 * 60 * 1000;
    let count: number = 0;
    for (const run of AgentService.get().runs.all()) {
      if (run.startedAt >= cutoff) {
        count += 1;
      }
    }
    return count;
  }

  private weekApps(): number {
    const cutoff: number = Date.now() - 7 * 24 * 60 * 60 * 1000;
    let count: number = 0;
    for (const run of AgentService.get().runs.all()) {
      if (run.startedAt >= cutoff && run.kind === 'ui.launch') {
        count += 1;
      }
    }
    return count;
  }

  private badge(run: RunRecord): string {
    if (run.kind === 'ui.launch') {
      return '📱 App';
    }
    if (run.kind === 'ui.type') {
      return '⌨️ Typing';
    }
    if (run.kind.startsWith('web.')) {
      return '🌐 Web';
    }
    return '⚙️ Task';
  }

  /** Shareable wording: no tool codes, no bridge jargon. */
  private title(run: RunRecord): string {
    if (run.status !== 'executed') {
      return 'That one did not work';
    }
    if (run.kind === 'ui.launch') {
      return 'Opened an app';
    }
    if (run.kind === 'ui.type') {
      return 'Typed a message';
    }
    if (run.kind === 'ui.tap') {
      return 'Tapped through a screen';
    }
    if (run.kind.startsWith('web.')) {
      return 'Browsed the web';
    }
    if (run.kind === 'sandbox.run') {
      return 'Ran a small script';
    }
    return 'Did something on the phone';
  }

  private async share(run: RunRecord): Promise<void> {
    const text: string = this.title(run);
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, `${text} — done by HOPA`);
      await pasteboard.getSystemPasteboard().setData(data);
      this.getUIContext().getPromptAction().showToast({ message: 'Copied — share it anywhere' });
    } catch (error) {
      // Clipboard is best effort.
    }
  }

  @Builder
  FeedCard(run: RunRecord, index: number) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.badge(run))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.accent())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(7)
        Blank()
        Text(new Date(run.startedAt).toLocaleTimeString())
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      Text(this.title(run))
        .fontSize(this.style().body + 1)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(2)
      if (run.shot.length > 0) {
        Image('file://' + run.shot)
          .width(100)
          .height(170)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
          .border({ width: 1, color: $r('app.color.divider') })
      }
      Row({ space: 8 }) {
        Text('Share')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accent())
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(8)
          .onClick(() => {
            this.share(run);
          })
        Text('Replay')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(8)
          .onClick(() => {
            this.onOpenRuns();
          })
        Blank()
        Circle({ width: 6, height: 6 })
          .fill(run.status === 'executed' ? $r('app.color.success') : $r('app.color.danger'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(this.style().cardRadius)
    .alignItems(HorizontalAlign.Start)
    .accessibilityText(`Open ${this.title(run)}`)
    .onClick(() => {
      this.selected = index;
    })
  }

  @Builder
  Detail(run: RunRecord) {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.selected = -1;
          })
        Text('What HOPA did')
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      Text(new Date(run.startedAt).toLocaleString())
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 10 }) {
        Text(this.badge(run))
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.accent())
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(7)
        Text(this.title(run))
          .fontSize(this.style().body + 5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(run.status === 'executed'
          ? `Finished in ${run.durationMs} ms`
          : 'This one did not finish')
          .fontSize(this.style().body - 1)
          .fontColor(run.status === 'executed'
            ? $r('app.color.success')
            : $r('app.color.danger'))
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(this.style().cardRadius)
      .alignItems(HorizontalAlign.Start)
      Blank()
      Row({ space: 10 }) {
        Text('Share')
          .fontSize(this.style().body)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.accent())
          .layoutWeight(1)
          .height(50)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(this.style().cardRadius)
          .onClick(() => {
            this.share(run);
          })
        Text('Replay')
          .fontSize(this.style().body)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_primary'))
          .layoutWeight(1)
          .height(50)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.accent())
          .borderRadius(this.style().cardRadius)
          .onClick(() => {
            this.onOpenRuns();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 30, bottom: 20 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.selected >= 0 && this.selected < this.feed().length) {
      this.Detail(this.feed()[this.selected])
    } else {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        HopaMark({ state: 'idle', markSize: 34, interactive: false })
        Column({ space: 1 }) {
          Text('HOPA')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(`${this.todayCount()} things done today`)
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')

      Column({ space: 6 }) {
        Row({ space: 6 }) {
          Text('THE ASSISTANT')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accent())
            .letterSpacing(0.7)
            .layoutWeight(1)
          Text(this.showFailures ? 'Hide failures' : 'Show failures')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.surface_alt'))
            .borderRadius(8)
            .margin({ right: 6 })
            .onClick(() => {
              this.showFailures = !this.showFailures;
            })
          Text('Ask HOPA')
            .fontSize(10.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_primary'))
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(this.accent())
            .borderRadius(9)
            .onClick(() => {
              this.onOpenChat('', false);
            })
        }
        .width('100%')
        Text(`${this.weekCount()} actions this week \u00b7 ${this.weekApps()} apps`)
          .fontSize(12)
          .fontColor($r('app.color.text_primary'))
        Text('Messages, posts and payments still ask you first.')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(this.style().cardRadius)
      .alignItems(HorizontalAlign.Start)

      if (this.feed().length === 0) {
        Column({ space: 8 }) {
          HopaMark({ state: 'happy', markSize: 72 })
          Text('Nothing here yet')
            .fontSize(this.style().body + 2)
            .fontWeight(FontWeight.Bold)
          Text('Ask HOPA to do something, then share it here.')
            .fontSize(this.style().body - 2)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 40, bottom: 20 })
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.feed(), (run: RunRecord, index: number) => {
              this.FeedCard(run, index)
            }, (run: RunRecord) => run.id)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      Row({ space: 10 }) {
        Text('+')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_primary'))
        Text('Ask HOPA')
          .fontSize(this.style().body + 1)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.on_primary'))
      }
      .width('100%')
      .height(54)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.accent())
      .borderRadius(this.style().cardRadius)
      .onClick(() => {
        // A feed action starts a fresh conversation, never appends to the last.
        AgentService.get().conversations.newChat();
        this.onOpenChat('', false);
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 30, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
    }
  }
}
