import { AgentService } from '../../services/AgentService';
import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Boomer-first home: one huge talk button, three big tiles, no chat in front. */
@Component
export struct EasyHome {
  onOpenChat: (goal: string, voice: boolean) => void = () => {};
  onOpenRuns: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'easy';
  @StorageLink('hopa.accent') accentColor: string = '';
  @State tick: number = 0;
  private ticker: number = -1;

  aboutToAppear(): void {
    // The run archive loads after the first frame; refresh the last row.
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
    // Easy keeps the calm brand blue; wallpaper colour belongs to the playful
    // profiles only.
    return $r('app.color.primary');
  }

  private greeting(): string {
    const hour: number = new Date().getHours();
    return hour < 5 ? 'Still up?' : (hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening'));
  }

  /** Plain words only: no kind codes, no "PC bridge". */
  private lastDone(): string {
    const runs = AgentService.get().runs.all();
    if (runs.length === 0) {
      return 'Nothing yet. Touch the big button and just talk.';
    }
    const kind: string = runs[runs.length - 1].kind;
    if (kind === 'ui.launch') {
      return 'Opened an app for you';
    }
    if (kind === 'ui.type') {
      return 'Typed something for you';
    }
    if (kind === 'ui.tap') {
      return 'Pressed a button for you';
    }
    if (kind.startsWith('web.')) {
      return 'Looked something up on the web';
    }
    if (kind === 'sandbox.run') {
      return 'Ran a small task for you';
    }
    return 'Did a job on your phone';
  }

  /** White outline mic: the emoji goes black and disappears on the blue button. */
  @Builder
  MicWhite() {
    Column() {
      Column()
        .width(9)
        .height(15)
        .borderRadius(5)
        .backgroundColor(Color.White)
      Column()
        .width(2)
        .height(4)
        .backgroundColor(Color.White)
      Column()
        .width(12)
        .height(2)
        .borderRadius(1)
        .backgroundColor(Color.White)
    }
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  Tile(label: string, hint: string, goal: string) {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(label)
          .fontSize(this.style().body + 1)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(hint)
          .fontSize(this.style().body - 3)
          .fontColor($r('app.color.text_hint'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(24)
        .fontColor(this.accent())
    }
    .width('100%')
    .padding({ left: 18, right: 16, top: 16, bottom: 16 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(this.style().cardRadius)
    .onClick(() => {
      this.onOpenChat(goal, false);
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          HopaMark({ state: 'idle', markSize: 56, animate: this.style().motion })
          Text(this.greeting())
            .fontSize(this.style().body)
            .fontColor($r('app.color.text_secondary'))
          Text('What would you like to do?')
            .fontSize(this.style().title - 6)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 12 })

        Row({ space: 12 }) {
          this.MicWhite()
          Text('Talk to HOPA')
            .fontSize(this.style().body + 3)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .height(68)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.accent())
        .borderRadius(this.style().cardRadius + 6)
        .shadow({ radius: 14, color: '#1F1C1B18', offsetY: 4 })
        .onClick(() => {
          this.onOpenChat('', true);
        })

        this.Tile('Send a message', 'Say it, and HOPA types it', 'Send a message to my family')
        this.Tile('Open my photos', 'HOPA opens the gallery for you', 'Open my photos')
        this.Tile('What can you do?', 'Hear the short list', 'What can you do on this phone?')

        Column({ space: 4 }) {
          Text('LAST TIME')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.6)
          Text(this.lastDone())
            .fontSize(this.style().body - 2)
            .fontColor($r('app.color.text_primary'))
            .maxLines(2)
          Text('Tap for the full history')
            .fontSize(this.style().body - 4)
            .fontColor($r('app.color.text_hint'))
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.surface_alt'))
        .borderRadius(this.style().cardRadius)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.onOpenRuns();
        })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 10, bottom: 24 })
      .constraintSize({ minHeight: '100%' })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
