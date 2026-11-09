import { RunRecord } from '@hopa/core';
import { pasteboard } from '@kit.BasicServicesKit';
import { AgentService } from '../../services/AgentService';
import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Gen Z home: a feed of what HOPA did, made to share. */
@Component
export struct SocialHome {
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenRuns: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'vivid';
  @StorageLink('hopa.accent') accentColor: string = '';
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

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private feed(): RunRecord[] {
    const all: RunRecord[] = AgentService.get().runs.all();
    return all.slice(Math.max(0, all.length - 6)).reverse();
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
  FeedCard(run: RunRecord) {
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
  }

  build() {
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
            ForEach(this.feed(), (run: RunRecord) => {
              this.FeedCard(run)
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
        this.onOpenChat('', false);
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 30, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }
}
