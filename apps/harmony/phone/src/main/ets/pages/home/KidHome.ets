import { Context, common } from '@kit.AbilityKit';
import { AgentService } from '../../services/AgentService';
import { Haptics } from '../../services/Haptics';
import { VisualStyle } from '../../services/VisualStyle';
import { VoiceController } from '../../services/VoiceController';
import { TaskRunner } from '../../services/TaskRunner';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';
import { HopaMark } from '../chat/HopaMark';

/**
 * Kid home: four big picture tiles, direct app launches, and one simple talk
 * sheet. No Everyday chat, no tabs, no history.
 */
@Component
export struct KidHome {
  onOpenSettings: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'vivid';
  @StorageLink('hopa.accent') accentColor: string = '';
  @State @Watch('syncFocus') taskOpen: boolean = false;
  @State phase: string = 'input';
  @State draft: string = '';
  @State result: string = '';
  @State stepText: string = '';
  @State recording: boolean = false;
  @State pressed: number = -1;
  @State boop: boolean = false;
  @State phraseIndex: number = 0;
  @State kidPin: string = '';
  @State pinOpen: boolean = false;
  @State pinDraft: string = '';
  @State pinWrong: boolean = false;
  @State stars: number = 0;
  @State timerOpen: boolean = false;
  @State timerLeft: number = 0;
  @State timerDone: boolean = false;
  private timerHandle: number = -1;
  private boopTimer: number = -1;

  aboutToAppear(): void {
    SettingsStore.load(getContext(this) as Context).then((stored: StoredSettings) => {
      this.kidPin = stored.kidPin;
      this.stars = stored.kidStars;
    }).catch(() => {
      // No PIN and no stars is fine.
    });
  }

  private awardStar(): void {
    this.stars += 1;
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored: StoredSettings) => {
      stored.kidStars = this.stars;
      return SettingsStore.save(context, stored);
    }).catch(() => {
      // Stars are cosmetic.
    });
  }

  private openTimer(): void {
    this.timerOpen = true;
    this.timerLeft = 0;
    this.timerDone = false;
  }

  private closeTimer(): void {
    if (this.timerHandle >= 0) {
      clearInterval(this.timerHandle);
      this.timerHandle = -1;
    }
    this.timerOpen = false;
    this.timerLeft = 0;
    this.timerDone = false;
  }

  private startTimer(minutes: number): void {
    if (this.timerHandle >= 0) {
      clearInterval(this.timerHandle);
    }
    this.timerLeft = minutes * 60;
    this.timerDone = false;
    this.timerHandle = setInterval(() => {
      if (this.timerLeft > 1) {
        this.timerLeft -= 1;
        return;
      }
      this.timerLeft = 0;
      if (this.timerHandle >= 0) {
        clearInterval(this.timerHandle);
        this.timerHandle = -1;
      }
      this.timerDone = true;
      Haptics.attention();
      this.speak('Time is up!');
    }, 1000);
  }

  private timerLabel(): string {
    const minutes: number = Math.floor(this.timerLeft / 60);
    const seconds: number = this.timerLeft % 60;
    return `${minutes}:${seconds < 10 ? `0${seconds}` : `${seconds}`}`;
  }

  private openGrownUp(): void {
    if (this.kidPin.length > 0) {
      this.pinDraft = '';
      this.pinWrong = false;
      this.pinOpen = true;
      return;
    }
    this.onOpenSettings();
  }

  private unlock(): void {
    if (this.pinDraft === this.kidPin) {
      this.pinOpen = false;
      this.onOpenSettings();
      return;
    }
    this.pinWrong = true;
  }

  private phrases(): string[] {
    return [
      "Tap me!", "Let's play!", "Boop!", "I'm HOPA!", "Pick one!", "Wheee!",
      "Hello hello!", "Again!", "Yay!", "High five!", "Peekaboo!", "Ready?",
      "Zoom zoom!", "Bounce!", "Silly me!", "You found me!", "Let's go!", "Hooray!",
      "One more!", "Ta-da!", "Beep boop!", "I like you!", "What's this?", "Magic!",
      "Spin spin!"
    ];
  }

  private boopNow(): void {
    Haptics.tap();
    this.phraseIndex = (this.phraseIndex + 1) % this.phrases().length;
    this.boop = true;
    if (this.boopTimer >= 0) {
      clearTimeout(this.boopTimer);
    }
    this.boopTimer = setTimeout(() => {
      this.boop = false;
      this.boopTimer = -1;
    }, 320);
  }

  private tileColor(index: number): string {
    const colors: string[] = ['#FFF1E8', '#EAF4FF', '#EEF8EC', '#FFF4CC'];
    return colors[index % colors.length];
  }
  private voice: VoiceController = new VoiceController();
  private runner: TaskRunner = new TaskRunner();

  syncFocus(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', this.taskOpen);
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', false);
    if (this.timerHandle >= 0) {
      clearInterval(this.timerHandle);
      this.timerHandle = -1;
    }
    if (this.boopTimer >= 0) {
      clearTimeout(this.boopTimer);
      this.boopTimer = -1;
    }
    this.clearPoll();
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.voice.release();
  }

  private style(): VisualStyle {
    return VisualStyle.of(this.styleName);
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private clearPoll(): void {
    this.runner.clear();
  }

  // ---- direct launches -------------------------------------------------

  private async launchApp(bundle: string): Promise<void> {
    const service = AgentService.get();
    if (!service.isBridgeConfigured()) {
      this.toast('A grown-up needs to finish setting this up.');
      return;
    }
    const opened: boolean = await service.bridge.launch(bundle);
    if (!opened) {
      this.toast("I couldn't open that one.");
    }
  }

  // ---- talk sheet ------------------------------------------------------

  private openTask(voice: boolean): void {
    this.taskOpen = true;
    this.phase = 'input';
    this.draft = '';
    this.result = '';
    this.stepText = '';
    if (voice) {
      this.startVoice();
    }
  }

  private closeTask(): void {
    this.clearPoll();
    this.runner.cancel();
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.taskOpen = false;
  }

  private async startVoice(): Promise<void> {
    const allowed: boolean = await this.voice.start(getContext(this) as common.UIAbilityContext);
    if (!allowed) {
      this.toast('I need the microphone to listen.');
      return;
    }
    this.recording = true;
  }

  private async stopVoice(): Promise<void> {
    this.recording = false;
    const heard: string = await this.voice.stop();
    if (heard.length === 0) {
      this.toast("I didn't catch that — try again.");
      return;
    }
    this.draft = heard;
  }

  private async speak(text: string): Promise<void> {
    await this.voice.speak(text, getContext(this) as common.UIAbilityContext);
  }

  private async runTask(): Promise<void> {
    const goal: string = this.draft.trim();
    if (goal.length === 0 || this.phase === 'working') {
      return;
    }
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.phase = 'working';
    this.stepText = 'Getting ready';
    let reply: string = '';
    try {
      reply = await this.runner.run(goal, (line: string) => {
        this.stepText = line;
      });
    } catch (error) {
      reply = 'Something went wrong. Let us try again.';
    }
    this.result = reply;
    this.phase = 'done';
    const low: string = reply.toLowerCase();
    if (!low.includes('something went wrong') && !low.includes("couldn't")) {
      this.awardStar();
    }
    this.speak(reply);
  }

  // ---- builders --------------------------------------------------------

  @Builder
  MicWhite(size: number) {
    Column() {
      Column()
        .width(size * 0.42)
        .height(size * 0.68)
        .borderRadius(size * 0.22)
        .backgroundColor(Color.White)
      Column()
        .width(size * 0.1)
        .height(size * 0.18)
        .backgroundColor(Color.White)
      Column()
        .width(size * 0.56)
        .height(size * 0.1)
        .borderRadius(size * 0.05)
        .backgroundColor(Color.White)
    }
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  Tile(index: number, icon: string, label: string, action: () => void) {
    Column({ space: 8 }) {
      Text(icon)
        .fontSize(42)
      Text(label)
        .fontSize(this.style().body + 1)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(120)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.tileColor(index))
    .border({ width: 1, color: '#141C1B18' })
    .borderRadius(this.style().cardRadius)
    .shadow({ radius: 10, color: '#0D1C1B18', offsetY: 2 })
    .scale({ x: this.pressed === index ? 0.95 : 1, y: this.pressed === index ? 0.95 : 1 })
    .animation({ duration: 110, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = index;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = -1;
      }
    })
    .accessibilityText(label)
    .onClick(action)
  }

  @Builder
  Home() {
    // Footer floats so the play area is centred in the full page: equal top
    // and bottom margins.
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 24 }) {
        Column({ space: 6 }) {
          Stack({ alignContent: Alignment.Center }) {
            HopaMark({ state: 'idle', markSize: 104, animate: true, interactive: false })
            Row()
              .width(104)
              .height(104)
              .onClick(() => {
                this.boopNow();
              })
          }
          .scale({ x: this.boop ? 1.08 : 1, y: this.boop ? 1.08 : 1 })
          .rotate({ angle: this.boop ? -5 : 0 })
          .animation({ duration: 180, curve: Curve.EaseOut })
          Text("Hi! I'm HOPA")
            .fontSize(this.style().body + 8)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text(this.phrases()[this.phraseIndex])
            .fontSize(this.style().body)
            .fontColor(this.accent())
          if (this.stars > 0) {
            Text(this.stars > 5
              ? `\u2b50 x${this.stars}`
              : '\u2b50'.repeat(this.stars))
              .fontSize(16)
              .letterSpacing(2)
              .fontColor(this.accent())
          }
        }
        .width('100%')

        Row({ space: 14 }) {
          this.Tile(0, '🎤', 'Talk', () => { this.openTask(true); })
          this.Tile(4, '📸', 'Camera', () => { this.launchApp('com.huawei.hmos.camera'); })
        }
        .width('100%')
        Row({ space: 14 }) {
          this.Tile(1, '🖼', 'Photos', () => { this.launchApp('com.huawei.hmos.photos'); })
          this.Tile(2, '🎵', 'Music', () => { this.launchApp('com.huawei.hmsapp.music'); })
        }
        .width('100%')
        Row({ space: 14 }) {
          this.Tile(3, '📝', 'Notes', () => { this.launchApp('com.huawei.hmos.notepad'); })
          this.Tile(5, '⏱', 'Timer', () => { this.openTimer(); })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 20, top: 20, bottom: 20 })

      Text('A grown-up can tap here for Settings')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 10, bottom: 16 })
        .onClick(() => {
          this.openGrownUp();
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PinGate() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
      Column({ space: 10 }) {
        Text('Grown-ups only')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('Enter the parent PIN to open Settings.')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
        TextInput({ text: this.pinDraft, placeholder: '4 digits' })
          .type(InputType.Number)
          .maxLength(4)
          .height(44)
          .fontSize(17)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(10)
          .onChange((value: string) => {
            this.pinDraft = value;
            this.pinWrong = false;
          })
        if (this.pinWrong) {
          Text('That PIN is not right.')
            .fontSize(11)
            .fontColor($r('app.color.danger'))
        }
        Row({ space: 10 }) {
          Text('Cancel')
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .textAlign(TextAlign.Center)
            .height(44)
            .layoutWeight(1)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(12)
            .onClick(() => {
              this.pinOpen = false;
            })
          Text('Unlock')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.on_primary'))
            .textAlign(TextAlign.Center)
            .height(44)
            .layoutWeight(1)
            .backgroundColor(this.accent())
            .borderRadius(12)
            .onClick(() => {
              this.unlock();
            })
        }
        .width('100%')
      }
      .width('82%')
      .padding(18)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(18)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  Sheet() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.closeTask();
          })
        Text(this.phase === 'done'
          ? "Here's what I did"
          : (this.phase === 'working' ? 'Working' : 'Talk to me'))
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      if (this.phase === 'input') {
        TextArea({ placeholder: 'Say or type what you want', text: this.draft })
          .width('100%')
          .height(140)
          .fontSize(this.style().body + 1)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(this.style().cardRadius)
          .padding(14)
          .onChange((value: string) => {
            this.draft = value;
          })
        Row({ space: 10 }) {
          if (this.recording) {
            Column()
              .width(12)
              .height(12)
              .borderRadius(3)
              .backgroundColor(Color.White)
          } else if (this.draft.trim().length > 0) {
            Text('↑')
              .fontSize(24)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          } else {
            this.MicWhite(20)
          }
          Text(this.recording
            ? 'Listening — tap to stop'
            : (this.draft.trim().length > 0 ? 'Send' : 'Say it'))
            .fontSize(this.style().body + 1)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')
        .height(64)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.recording ? $r('app.color.danger') : this.accent())
        .borderRadius(this.style().cardRadius)
        .onClick(() => {
          if (this.recording) {
            this.stopVoice();
          } else if (this.draft.trim().length > 0) {
            this.runTask();
          } else {
            this.startVoice();
          }
        })
      } else if (this.phase === 'working') {
        Column({ space: 20 }) {
          HopaMark({ state: 'acting', markSize: 80, interactive: false })
          Text(this.stepText.length > 0 ? this.stepText : 'Getting ready')
            .fontSize(this.style().body + 3)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
          Text(this.draft)
            .fontSize(this.style().body)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(3)
          Text('Stop')
            .fontSize(this.style().body + 1)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.danger'))
            .borderRadius(this.style().cardRadius)
            .margin({ top: 12 })
            .onClick(() => {
              this.runner.cancel();
            })
        }
        .width('100%')
        .padding({ top: 32 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Column({ space: 16 }) {
          HopaMark({ state: 'happy', markSize: 64, interactive: false })
          Text(this.draft)
            .fontSize(this.style().body - 1)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Scroll() {
            Text(this.result)
              .fontSize(this.style().body + 3)
              .lineHeight(this.style().body + 12)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 340 })
          .scrollBar(BarState.Off)
          Blank()
          Text('Say something else')
            .fontSize(this.style().body + 1)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_primary'))
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.accent())
            .borderRadius(this.style().cardRadius)
            .onClick(() => {
              this.phase = 'input';
              this.draft = '';
              this.result = '';
            })

        }
        .width('100%')
        .height('100%')
        .padding({ top: 24 })
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 40, bottom: 48 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TimerSheet() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg'))
      Column({ space: 20 }) {
        Row({ space: 8 }) {
          Text('\u2190')
            .fontSize(24)
            .fontColor($r('app.color.text_primary'))
            .width(44)
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.closeTimer();
            })
          Text('Timer')
            .fontSize(this.style().body + 3)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
        }
        .width('100%')
        if (this.timerDone) {
          Text('\u23F1')
            .fontSize(72)
          Text('Time is up!')
            .fontSize(this.style().body + 14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accent())
          Text('Done')
            .fontSize(this.style().body + 1)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_primary'))
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.accent())
            .borderRadius(this.style().cardRadius)
            .onClick(() => {
              this.closeTimer();
            })
        } else if (this.timerLeft > 0) {
          Text(this.timerLabel())
            .fontSize(this.style().body + 40)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('Time left')
            .fontSize(this.style().body - 2)
            .fontColor($r('app.color.text_hint'))
          Text('Stop')
            .fontSize(this.style().body + 1)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .width('100%')
            .height(56)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.danger'))
            .borderRadius(this.style().cardRadius)
            .onClick(() => {
              this.closeTimer();
            })
        } else {
          Text('How long?')
            .fontSize(this.style().body + 6)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Row({ space: 12 }) {
            ForEach([1, 3, 5], (minutes: number) => {
              Text(`${minutes} min`)
                .fontSize(this.style().body + 1)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .height(64)
                .textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.surface'))
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(this.style().cardRadius)
                .onClick(() => {
                  this.startTimer(minutes);
                })
            }, (minutes: number) => `${minutes}`)
          }
          .width('100%')
          Text('A grown-up can stop it any time.')
            .fontSize(this.style().body - 4)
            .fontColor($r('app.color.text_hint'))
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 40, bottom: 48 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.Home()
      if (this.taskOpen) {
        this.Sheet()
      }
      if (this.pinOpen) {
        this.PinGate()
      }
      if (this.timerOpen) {
        this.TimerSheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
