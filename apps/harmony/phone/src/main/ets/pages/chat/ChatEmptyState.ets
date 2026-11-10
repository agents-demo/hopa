/** The first screen of a new chat: brand, promise and three suggestions. */
import { HopaMark } from './HopaMark';
import { AgentService } from '../../services/AgentService';
import { SettingsStore } from '../../services/SettingsStore';
import { VisualStyle } from '../../services/VisualStyle';
import { ModeProfile } from '../../services/ModeProfile';
import { Character } from '../../services/Character';
import { APP_CATALOG } from '../../services/AppCatalog';
import { Context } from '@kit.AbilityKit';

@Component
export struct ChatEmptyState {
  onPick: (text: string) => void = () => {};
  /** Opens the last conversation; Reuse is the only way to send it again. */
  onResume: () => void = () => {};
  onTrust: () => void = () => {};
  @Prop resume: string = '';
  @Prop resumeAt: number = 0;
  @Prop hasEarlier: boolean = false;
  @Prop listening: boolean = false;
  @State entered: boolean = false;
  @State pressed: number = -1;
  @State greeting: string = 'Hi';
  /** With history the screen stays quiet; examples are one tap away. */
  @State ideasOpen: boolean = false;
  @State promptTick: number = 0;
  @StorageLink('hopa.accent') accentColor: string = '';
  @StorageLink('hopa.style') styleName: string = 'calm';
  @StorageLink('hopa.profile') profileName: string = 'everyday';

  private style(): VisualStyle {
    return VisualStyle.of(this.styleName);
  }

  private profile(): ModeProfile {
    return ModeProfile.of(this.profileName);
  }

  private tagline(): string {
    return Character.tagline(this.profile().name);
  }

  private accent(): ResourceColor {
    const profile = ModeProfile.of(this.profileName);
    if (profile.name !== 'social' && profile.name !== 'kid') {
      return $r('app.color.primary');
    }
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private accentTint(alpha: string): string {
    const profile = ModeProfile.of(this.profileName);
    if (profile.name !== 'social' && profile.name !== 'kid') {
      return `#${alpha}0A59F7`;
    }
    return this.accentColor.length > 0 ? `#${alpha}${this.accentColor.substring(1)}` : `#${alpha}E8703A`;
  }

  /** The last-conversation card is a quiet reminder, not a primary action. */
  private quietCard(): boolean {
    const name: string = this.profile().name;
    return name === 'everyday' || name === 'power';
  }

  aboutToAppear(): void {
    const hour: number = new Date().getHours();
    this.greeting = Character.greeting(hour);
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

  private resumeWhen(): string {
    if (this.resumeAt <= 0) {
      return '';
    }
    const minutes: number = Math.floor((Date.now() - this.resumeAt) / 60000);
    if (minutes <= 1) {
      return 'just now';
    }
    if (minutes < 60) {
      return `${minutes} min ago`;
    }
    const hours: number = Math.floor(minutes / 60);
    if (hours < 24) {
      return hours === 1 ? 'an hour ago' : `${hours} hours ago`;
    }
    const days: number = Math.floor(hours / 24);
    if (days === 1) {
      return 'yesterday';
    }
    return days < 7 ? `${days} days ago` : 'last week';
  }

  private dayKey(kind: string): string {
    const now = new Date();
    return `hopa.dismissed.${kind}.${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
  }

  private dismissed(kind: string): boolean {
    return (AppStorage.get<string>(this.dayKey(kind)) ?? '').length > 0;
  }

  private dismiss(kind: string): void {
    AppStorage.setOrCreate<string>(this.dayKey(kind), '1');
    this.promptTick += 1;
  }

  private ritualTitle(): string {
    const hour: number = new Date().getHours();
    if (hour >= 5 && hour < 12) {
      return 'Morning brief';
    }
    if (hour >= 18) {
      return 'Evening close';
    }
    return '';
  }

  private ritualGoal(): string {
    const hour: number = new Date().getHours();
    if (hour >= 5 && hour < 12) {
      return 'What should I get done this morning?';
    }
    if (hour >= 18) {
      return 'What did I get done today?';
    }
    return '';
  }

  /** A goal the user has asked more than once, so offering it is useful. */
  private repeatGoal(): string {
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
        if (goal.toLowerCase() === this.resume.toLowerCase()) {
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
    let best: number = 1;
    let goal: string = '';
    for (let i = 0; i < goals.length; i++) {
      if (counts[i] > best) {
        best = counts[i];
        goal = goals[i];
      }
    }
    return goal;
  }

  private promptKind(): string {
    if (!this.dismissed('ritual') && this.ritualTitle().length > 0) {
      return 'ritual';
    }
    if (!this.dismissed('again') && this.repeatGoal().length > 0) {
      return 'again';
    }
    return '';
  }

  private promptTitle(): string {
    return this.promptKind() === 'ritual' ? this.ritualTitle() : 'Again?';
  }

  private promptGoal(): string {
    return this.promptKind() === 'ritual' ? this.ritualGoal() : this.repeatGoal();
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

  private appCount(): number {
    let count: number = 0;
    for (const app of APP_CATALOG) {
      if (app.confirmed) {
        count += 1;
      }
    }
    return count;
  }

  private factCount(): number {
    return AgentService.get().memory.all().length;
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
        // One line in Calm, as before the profile work; bigger only where the
        // profile asks for larger text.
        .fontSize(this.style().body - 1)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Text('I always ask before any payment.')
        .fontSize(this.style().body - 4)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 8 }) {
        Row({ space: 6 }) {
          Text('HOPA can use')
            .fontSize(10)
            .fontColor($r('app.color.text_hint'))
          Text(`${this.appCount()} apps, ${this.factCount()} facts`)
            .fontSize(10)
            .fontColor(this.accent())
          Text('Review')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent())
        }
        .padding({ left: 2, top: 2 })
        .onClick(() => {
          this.onTrust();
        })
        if (this.promptKind().length > 0) {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text(this.promptTitle())
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.accent())
                .letterSpacing(0.6)
              Text(this.promptGoal())
                .fontSize(12.5)
                .fontColor($r('app.color.text_primary'))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('Run')
              .fontSize(10.5)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(this.accent())
              .borderRadius(9)
              .onClick(() => {
                this.onPick(this.promptGoal());
              })
            Text('\u00d7')
              .fontSize(15)
              .fontColor($r('app.color.text_hint'))
              .padding(5)
              .onClick(() => {
                this.dismiss(this.promptKind());
              })
          }
          .width('100%')
          .padding({ left: 12, right: 8, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(12)
        }
        if (this.hasResume()) {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text('Last conversation')
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.quietCard() ? $r('app.color.text_hint') : this.accent())
                .letterSpacing(0.6)
              Text(this.resume)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.resumeWhen().length > 0
                ? `${this.resumeWhen()} \u00b7 Tap to open`
                : 'Tap to open it')
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('›')
              .fontSize(18)
              .fontColor(this.quietCard() ? $r('app.color.text_secondary') : this.accent())
          }
          .width('100%')
          .padding({ left: 12, right: 10, top: 9, bottom: 9 })
          .border({
            width: 1,
            color: this.quietCard() ? $r('app.color.divider') : this.accentTint('26')
          })
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
