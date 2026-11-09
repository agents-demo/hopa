/** The first screen of a new chat: brand, promise and three suggestions. */
import { HopaMark } from './HopaMark';
import { AgentService } from '../../services/AgentService';
import { SettingsStore } from '../../services/SettingsStore';
import { StyleProfile } from '../../services/StyleProfile';
import { ProfileService } from '../../services/ProfileService';
import { Context } from '@kit.AbilityKit';

@Component
export struct ChatEmptyState {
  onPick: (text: string) => void = () => {};
  /** Opens the last conversation; Reuse is the only way to send it again. */
  onResume: () => void = () => {};
  @Prop resume: string = '';
  @Prop hasEarlier: boolean = false;
  @Prop listening: boolean = false;
  @State entered: boolean = false;
  @State pressed: number = -1;
  @State greeting: string = 'Hi';
  /** With history the screen stays quiet; examples are one tap away. */
  @State ideasOpen: boolean = false;
  @StorageLink('hopa.accent') accentColor: string = '';
  @StorageLink('hopa.style') styleName: string = 'calm';
  @StorageLink('hopa.profile') profileName: string = 'everyday';

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  private profile(): ProfileService {
    return ProfileService.of(this.profileName);
  }

  private tagline(): string {
    if (this.profile().language === 'plain') {
      return 'Type or say what you need. I will do it on this phone.';
    }
    if (this.profile().language === 'playful') {
      return 'What are we doing today?';
    }
    return 'Your phone agent. Ask for something on this phone.';
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private accentTint(alpha: string): string {
    return this.accentColor.length > 0 ? `#${alpha}${this.accentColor.substring(1)}` : `#${alpha}E8703A`;
  }

  aboutToAppear(): void {
    const hour: number = new Date().getHours();
    this.greeting = hour < 5 ? 'Still up?' : (hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening'));
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored) => {
      if (stored.reduceMotion || !this.style().motion) {
        this.entered = true;
      }
    }).catch(() => {
      // Keep the default animation.
    });
    // A soft entrance: content lifts in instead of appearing fully formed.
    animateTo({ duration: 420, curve: Curve.EaseOut }, () => {
      this.entered = true;
    });
  }

  private suggestions(): string[] {
    return [
      'Open Bilibili and show me the 3 most popular videos',
      'Open Settings and show me Wi-Fi',
      'Draft a one-line message to my team'
    ];
  }

  private hasResume(): boolean {
    return this.resume.length > 0 && this.hasEarlier && !this.suggestions().includes(this.resume);
  }

  private pick(index: number, text: string): void {
    this.pressed = index;
    setTimeout(() => {
      this.pressed = -1;
    }, 140);
    this.onPick(text);
  }

  build() {
    Column({ space: 12 }) {
      HopaMark({
        state: this.listening ? 'listening' : 'idle',
        markSize: this.style().mascot,
        animate: this.style().motion
      })
      Text(this.greeting)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .letterSpacing(0.4)
      Text('HOPA')
        .fontSize(this.style().title)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .letterSpacing(-0.4)
      Text(this.tagline())
        .fontSize(this.style().body)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Text('I always ask before any payment.')
        .fontSize(this.style().body - 4)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 8 }) {
        if (this.hasResume()) {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text('Last conversation')
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.accent())
                .letterSpacing(0.6)
              Text(this.resume)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text('Tap to open it')
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('›')
              .fontSize(18)
              .fontColor(this.accent())
          }
          .width('100%')
          .padding({ left: 12, right: 10, top: 9, bottom: 9 })
          .border({ width: 1, color: this.accentTint('26') })
          .borderRadius(12)
          .opacity(this.pressed === -1 ? 1 : 0.62)
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onClick(() => {
            this.onResume();
          })
        }
        if (this.hasResume() && this.profile().discovery === 'guided') {
          Row({ space: 4 }) {
            Text(this.ideasOpen ? 'Hide examples' : 'Try an example')
              .fontSize(11)
              .fontColor(this.accent())
            Text(this.ideasOpen ? '↑' : '↓')
              .fontSize(10)
              .fontColor(this.accent())
          }
          .padding({ left: 2, top: 2, bottom: 2 })
          .onClick(() => {
            this.ideasOpen = !this.ideasOpen;
          })
        } else if (!this.hasResume()) {
          Text('TRY SOMETHING')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_hint'))
            .letterSpacing(0.7)
            .width('100%')
            .padding({ left: 2, top: 2 })
        }
        if (!this.hasResume() || this.ideasOpen) {
        ForEach(this.suggestions(), (suggestion: string, index: number) => {
          Row() {
            Text(suggestion)
              .fontSize(this.style().body - 2.5)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: this.style().motion ? 12 : 14, bottom: this.style().motion ? 12 : 14 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: '#0F1C1B18' })
          .borderRadius(this.style().cardRadius)
          .shadow({ radius: 10, color: '#0A1C1B18', offsetY: 2 })
          .scale({ x: this.pressed === index ? 0.985 : 1, y: this.pressed === index ? 0.985 : 1 })
          .animation({ duration: 140, curve: Curve.EaseOut })
          .onClick(() => {
            this.pick(index, suggestion);
          })
        }, (suggestion: string) => suggestion)
        }
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .opacity(this.entered ? 1 : 0)
    .translate({ y: this.entered ? 0 : 10 })
    .animation({ duration: 420, curve: Curve.EaseOut })
  }
}
