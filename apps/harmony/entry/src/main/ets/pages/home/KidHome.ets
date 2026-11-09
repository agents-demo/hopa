import { Context, Permissions, abilityAccessCtrl, common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AgentService } from '../../services/AgentService';
import { Haptics } from '../../services/Haptics';
import { StyleProfile } from '../../services/StyleProfile';
import { VoiceService } from '../../services/VoiceService';
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
  private boopTimer: number = -1;

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
  private poll: number = -1;
  private voice: VoiceService = new VoiceService();

  syncFocus(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', this.taskOpen);
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', false);
    if (this.boopTimer >= 0) {
      clearTimeout(this.boopTimer);
      this.boopTimer = -1;
    }
    this.clearPoll();
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.voice.releasePlayer();
  }

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  private accent(): ResourceColor {
    return this.accentColor.length > 0 ? this.accentColor : $r('app.color.primary');
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private clearPoll(): void {
    if (this.poll >= 0) {
      clearInterval(this.poll);
      this.poll = -1;
    }
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
    AgentService.get().cancel();
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.taskOpen = false;
  }

  private async ensureMic(): Promise<boolean> {
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
      const result = await manager.requestPermissionsFromUser(
        getContext(this) as common.UIAbilityContext, permissions);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (error) {
      return false;
    }
  }

  private async startVoice(): Promise<void> {
    if (this.recording) {
      return;
    }
    const allowed: boolean = await this.ensureMic();
    if (!allowed) {
      this.toast('I need the microphone to listen.');
      return;
    }
    try {
      await this.voice.start();
      this.recording = true;
    } catch (error) {
      this.recording = false;
      this.toast('I could not start listening.');
    }
  }

  private async stopVoice(): Promise<void> {
    if (!this.recording) {
      return;
    }
    this.recording = false;
    let wav: ArrayBuffer = new ArrayBuffer(0);
    try {
      wav = await this.voice.stop();
    } catch (error) {
      wav = new ArrayBuffer(0);
    }
    if (wav.byteLength <= 44) {
      this.toast("I didn't catch that — try again.");
      return;
    }
    try {
      const helper: util.Base64Helper = new util.Base64Helper();
      const heard: string = (await AgentService.get().bridge.transcribe(
        helper.encodeToStringSync(new Uint8Array(wav)))).trim();
      if (heard.length === 0) {
        this.toast("I didn't catch that — try again.");
        return;
      }
      this.draft = heard;
    } catch (error) {
      this.toast('A grown-up needs to turn on the PC helper.');
    }
  }

  private async speak(text: string): Promise<void> {
    const service = AgentService.get();
    if (!service.isBridgeConfigured() || text.length === 0) {
      return;
    }
    try {
      const audio: string = await service.bridge.speak(text.substring(0, 500));
      if (audio.length === 0) {
        return;
      }
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = helper.decodeSync(audio);
      const wav: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      await this.voice.speak(wav, getContext(this) as Context);
    } catch (error) {
      // Speaking is a bonus.
    }
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
    this.poll = setInterval(() => {
      const steps: string[] = AgentService.get().runtime.lastSteps();
      if (steps.length > 0) {
        this.stepText = steps[steps.length - 1].substring(2);
      }
    }, 500);
    let reply: string = '';
    try {
      reply = await AgentService.get().run(goal);
    } catch (error) {
      reply = 'Something went wrong. Let us try again.';
    }
    this.clearPoll();
    this.result = reply;
    this.phase = 'done';
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
    .height(140)
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
    .onClick(action)
  }

  @Builder
  Home() {
    // Footer floats so the play area is centred in the full page: equal top
    // and bottom margins.
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 34 }) {
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
        }
        .width('100%')

        Row({ space: 14 }) {
          this.Tile(0, '🎤', 'Talk', () => { this.openTask(true); })
          this.Tile(1, '📷', 'Photos', () => { this.launchApp('com.huawei.hmos.photos'); })
        }
        .width('100%')
        Row({ space: 14 }) {
          this.Tile(2, '🎵', 'Music', () => { this.launchApp('com.huawei.hmsapp.music'); })
          this.Tile(3, '📝', 'Draw', () => { this.launchApp('com.huawei.hmos.notepad'); })
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
          this.onOpenSettings();
        })
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
              AgentService.get().cancel();
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
          Text('Close')
            .fontSize(this.style().body - 1)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .onClick(() => {
              this.closeTask();
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.Home()
      if (this.taskOpen) {
        this.Sheet()
      }
    }
    .width('100%')
    .height('100%')
  }
}
