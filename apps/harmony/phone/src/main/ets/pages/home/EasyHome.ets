import { Context, Want, common } from '@kit.AbilityKit';
import { VisualStyle } from '../../services/VisualStyle';
import { VoiceController } from '../../services/VoiceController';
import { TaskRunner } from '../../services/TaskRunner';
import { Haptics } from '../../services/Haptics';
import { TaskLog } from '../../services/TaskLog';
import { HopaMark } from '../chat/HopaMark';
import { Character } from '../../services/Character';
import { AgentService } from '../../services/AgentService';

/**
 * Easy home: big choices, one task sheet, no Everyday chat screen.
 *
 * Preset launches run directly through the bridge (no session, no model),
 * while typed or spoken requests run in the sheet and show the answer there.
 */
@Component
export struct EasyHome {
  onOpenHistory: () => void = () => {};
  onOpenSettings: () => void = () => {};
  @StorageLink('hopa.style') styleName: string = 'easy';
  @StorageLink('hopa.accent') accentColor: string = '';
  @State @Watch('syncFocus') taskOpen: boolean = false;
  @State @Watch('syncFocus') helpOpen: boolean = false;
  @State phase: string = 'input';
  @State draft: string = '';
  @State result: string = '';
  @State stepText: string = '';
  @State recording: boolean = false;
  @State hello: boolean = false;
  @State padOpen: boolean = false;
  @State padNumber: string = '';
  private helloTimer: number = -1;
  private voice: VoiceController = new VoiceController();
  private runner: TaskRunner = new TaskRunner();

  /** The sheet owns the whole screen: no shell bar, no tabs, no "+". */
  syncFocus(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', this.taskOpen || this.helpOpen || this.padOpen);
  }

  aboutToAppear(): void {
    // "Ask again" from History reopens the sheet with the old request.
    if (AppStorage.get<boolean>('hopa.easyOpenTask') ?? false) {
      const draft: string = AppStorage.get<string>('hopa.easyDraft') ?? '';
      AppStorage.setOrCreate<boolean>('hopa.easyOpenTask', false);
      AppStorage.setOrCreate<string>('hopa.easyDraft', '');
      this.taskOpen = true;
      this.phase = 'input';
      this.draft = draft;
      this.result = '';
      this.stepText = '';
      this.syncFocus();
    }
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate<boolean>('hopa.focus', false);
    if (this.helloTimer >= 0) {
      clearTimeout(this.helloTimer);
      this.helloTimer = -1;
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

  private greet(): void {
    Haptics.tap();
    this.hello = true;
    if (this.helloTimer >= 0) {
      clearTimeout(this.helloTimer);
    }
    this.helloTimer = setTimeout(() => {
      this.hello = false;
      this.helloTimer = -1;
    }, 2800);
  }

  private greeting(): string {
    const hour: number = new Date().getHours();
    return hour < 5 ? 'Still up?' : (hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening'));
  }

  private clearPoll(): void {
    this.runner.clear();
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  // ---- task sheet ------------------------------------------------------

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

  private openPad(): void {
    this.padNumber = '';
    this.padOpen = true;
    this.syncFocus();
  }

  private closePad(): void {
    this.padOpen = false;
    this.syncFocus();
  }

  private digit(value: string): void {
    if (this.padNumber.length < 18) {
      this.padNumber = `${this.padNumber}${value}`;
    }
  }

  private backspace(): void {
    this.padNumber = this.padNumber.length > 0
      ? this.padNumber.substring(0, this.padNumber.length - 1)
      : '';
  }

  private async placeCall(): Promise<void> {
    if (this.padNumber.length === 0) {
      return;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.dial',
        uri: `tel:${this.padNumber}`
      };
      await (getContext(this) as common.UIAbilityContext).startAbility(want);
    } catch (error) {
      const opened: boolean = await AgentService.get().bridge.launch('com.ohos.contacts');
      if (!opened) {
        this.toast('Open Phone to finish the call.');
      }
    }
    this.closePad();
  }

  private async messageSomeone(): Promise<void> {
    const opened: boolean = await AgentService.get().bridge.launch('com.ohos.mms');
    if (!opened) {
      this.toast('Messages is not available.');
    }
  }

  private openTaskWith(draft: string): void {
    this.taskOpen = true;
    this.phase = 'input';
    this.result = '';
    this.stepText = '';
    this.draft = draft;
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
      reply = Character.failure(reply, 'easy');
    }
    this.result = reply;
    this.phase = 'done';
    TaskLog.add(getContext(this) as Context, goal, reply).catch(() => {
      // History is best effort; the answer is already on screen.
    });
    this.speak(reply);
  }

  // ---- builders --------------------------------------------------------

  private accent(): ResourceColor {
    return $r('app.color.primary');
  }

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

  /** Same shape as the talk button, so the two read as siblings. */
  @Builder
  Tile(label: string, action: () => void) {
    Text(label)
      .fontSize(this.style().body + 3)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .width('100%')
      .height(68)
      .textAlign(TextAlign.Center)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(this.style().cardRadius + 6)
      .accessibilityText(label)
      .onClick(action)
  }

  @Builder
  Home() {
    // The footer floats, so the content centres against the full page height
    // with the same gap above and below.
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 20 }) {
        Column({ space: 8 }) {
          Stack({ alignContent: Alignment.Center }) {
            HopaMark({
              state: 'idle',
              markSize: 56,
              animate: this.style().motion,
              interactive: false
            })
            // Transparent target: the mark's own hit area swallows taps.
            Row()
              .width(56)
              .height(56)
              .onClick(() => {
                this.greet();
              })
          }
          Text(this.hello ? 'Nice to meet you!' : this.greeting())
            .fontSize(this.style().body - 2)
            .fontColor(this.hello ? $r('app.color.primary') : $r('app.color.text_secondary'))
          Text('I am HOPA')
            .fontSize(this.style().body + 6)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .letterSpacing(-0.3)
        }
        .width('100%')
        .padding({ top: 12 })
        .margin({ bottom: 16 })
        .onClick(() => {
          this.greet();
        })

        Text('Talk to me')
          .fontSize(this.style().body + 3)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .width('100%')
          .height(68)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.accent())
          .borderRadius(this.style().cardRadius + 6)
          .shadow({ radius: 14, color: '#1F1C1B18', offsetY: 4 })
          .accessibilityText('Talk to HOPA')
          .onClick(() => {
            this.openTask(true);
          })

        this.Tile('Send a message', () => {
          this.messageSomeone();
        })

        this.Tile('Call someone', () => {
          this.openPad();
        })


        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 24, bottom: 24 })
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      Row({ space: 6 }) {
        Text('Help')
          .fontSize(this.style().body - 2)
          .fontColor($r('app.color.text_secondary'))
          .padding(8)
          .onClick(() => {
            this.helpOpen = true;
          })
        Text('·')
          .fontSize(this.style().body - 2)
          .fontColor($r('app.color.text_hint'))
        Text('History')
          .fontSize(this.style().body - 2)
          .fontColor($r('app.color.text_secondary'))
          .padding(8)
          .onClick(() => {
            this.onOpenHistory();
          })
        Text('·')
          .fontSize(this.style().body - 2)
          .fontColor($r('app.color.text_hint'))
        Text('Settings')
          .fontSize(this.style().body - 2)
          .fontColor($r('app.color.text_secondary'))
          .padding(8)
          .onClick(() => {
            this.onOpenSettings();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 2, bottom: 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TaskPanel() {
    Column({ space: 14 }) {
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
          : (this.phase === 'working' ? 'Working' : 'What should I do?'))
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      if (this.phase === 'input') {
        TextArea({ placeholder: 'For example: message my daughter that I am on my way', text: this.draft })
          .width('100%')
          .height(150)
          .fontSize(this.style().body + 1)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(this.style().cardRadius)
          .padding(14)
          .onChange((value: string) => {
            this.draft = value;
          })
        // One action, like the composer: mic when empty, send when there is text.
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
        .height(60)
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
            .fontColor($r('app.color.text_primary'))
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
          .constraintSize({ maxHeight: 380 })
          .scrollBar(BarState.Off)
          Blank()
          Text('Read it again')
            .fontSize(this.style().body)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent())
            .width('100%')
            .height(52)
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.divider') })
            .borderRadius(this.style().cardRadius)
            .onClick(() => {
              this.speak(this.result);
            })
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
  HelpPanel() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.helpOpen = false;
          })
        Text('What I can do')
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')

      Column({ space: 12 }) {
        Text('I can open apps, send messages, look things up, and walk through a page for you. I always ask before anything public or any payment.')
          .fontSize(this.style().body + 1)
          .lineHeight(this.style().body + 9)
          .fontColor($r('app.color.text_primary'))
        Text('Say things like:')
          .fontSize(this.style().body - 1)
          .fontColor($r('app.color.text_hint'))
        Text('"Open the camera"')
          .fontSize(this.style().body + 1)
          .fontColor($r('app.color.text_primary'))
        Text('“Text my daughter that I am on my way”')
          .fontSize(this.style().body + 1)
          .fontColor($r('app.color.text_primary'))
        Text('“What is the weather today?”')
          .fontSize(this.style().body + 1)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(this.style().cardRadius)
      .alignItems(HorizontalAlign.Start)

      Blank()
      Text('Got it')
        .fontSize(this.style().body + 1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.on_primary'))
        .width('100%')
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.accent())
        .borderRadius(this.style().cardRadius)
        .onClick(() => {
          this.helpOpen = false;
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 40, bottom: 48 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  Keypad() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('\u2190')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.closePad();
          })
        Text('Call')
          .fontSize(this.style().body + 3)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      Row({ space: 10 }) {
        Text(this.padNumber.length > 0 ? this.padNumber : 'Enter a number')
          .fontSize(this.padNumber.length > 0 ? this.style().body + 12 : this.style().body)
          .fontWeight(this.padNumber.length > 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.padNumber.length > 0
            ? $r('app.color.text_primary')
            : $r('app.color.text_hint'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.padNumber.length > 0) {
          Text('\u232b')
            .fontSize(22)
            .fontColor($r('app.color.text_secondary'))
            .width(48)
            .height(48)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.backspace();
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 14, right: 6 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(this.style().cardRadius)
      ForEach([['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['*', '0', '#']],
        (row: string[]) => {
          Row({ space: 10 }) {
            ForEach(row, (key: string) => {
              Text(key)
                .fontSize(this.style().body + 8)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .height(64)
                .textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.surface'))
                .border({ width: 1, color: $r('app.color.divider') })
                .borderRadius(this.style().cardRadius)
                .onClick(() => {
                  this.digit(key);
                })
            }, (key: string) => key)
          }
          .width('100%')
        }, (row: string[]) => row.join(''))
      Blank()
      Text('Call')
        .fontSize(this.style().body + 2)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .height(64)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.padNumber.length > 0
          ? $r('app.color.success')
          : $r('app.color.surface_muted'))
        .fontColor(this.padNumber.length > 0 ? Color.White : $r('app.color.text_hint'))
        .borderRadius(this.style().cardRadius + 4)
        .onClick(() => {
          this.placeCall();
        })
      Text('The phone will ask before the call goes out.')
        .fontSize(this.style().body - 4)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 40, bottom: 36 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.Home()
      if (this.taskOpen) {
        this.TaskPanel()
      }
      if (this.helpOpen) {
        this.HelpPanel()
      }
      if (this.padOpen) {
        this.Keypad()
      }
    }
    .width('100%')
    .height('100%')
  }
}
