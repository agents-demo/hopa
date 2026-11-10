import { Context, Want, common, wantConstant } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { SettingsStore } from '../../services/SettingsStore';
import { ChatEmptyState } from './ChatEmptyState';
import { ChatPageCard } from './ChatPageCard';
import { ChatComposer } from './ChatComposer';
import { ChatFormat } from './ChatFormat';
import { ErrorLog } from '../../services/ErrorLog';
import { RunNotification } from '../../services/RunNotification';
import { RecapCard } from './RecapCard';
import { ChatTyping } from './ChatTyping';
import { MessageActions } from './MessageActions';
import { ResultActions } from './ResultActions';
import { HopaMark } from './HopaMark';
import { Haptics } from '../../services/Haptics';
import { VoiceController } from '../../services/VoiceController';
import { AppFocus } from '../../services/AppFocus';
import { ModeProfile } from '../../services/ModeProfile';
import { Character } from '../../services/Character';
import { VisualStyle } from '../../services/VisualStyle';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { APP_CATALOG } from '../../services/AppCatalog';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Chat: the transcript, the empty state and the composer. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State reaction: string = '';
  @State resumeGoal: string = '';
  @State resumeAt: number = 0;
  @State loaded: boolean = false;
  @State diffText: string = '';
  @State trimmedCount: number = 0;
  @State canUndo: boolean = false;
  private undoSteps: string[] = [];
  @State runningGoal: string = '';
  @State failed: boolean = false;
  @State characterLine: string = '';
  @State liveSteps: string[] = [];
  @StorageLink('hopa.showSteps') showSteps: boolean = true;
  @State lastPageUrl: string = '';
  @State lastPageTitle: string = '';
  @State recording: boolean = false;
  @StorageLink('hopa.speak') speakReplies: boolean = false;
  @StorageLink('hopa.profile') profileName: string = 'everyday';
  @StorageLink('hopa.style') styleName: string = 'calm';
  /** Contents of the image rendered for "Share recap". */
  @State recapGoal: string = '';
  @State recapAnswer: string = '';
  @State recapSteps: string[] = [];
  private voice: VoiceController = new VoiceController();
  private seenVersion: number = -1;
  private timer: number = -1;
  private reactionTimer: number = -1;
  private listScroller: Scroller = new Scroller();
  private renderedCount: number = 0;

  aboutToAppear(): void {
    const service = AgentService.get();
    this.lastPageUrl = service.pageLinks.url();
    this.lastPageTitle = service.pageLinks.title();
    const context = getContext(this) as Context;
    SettingsStore.load(context).then((stored) => {
      this.showSteps = stored.showSteps;
      this.speakReplies = stored.speakReplies;
    }).catch(() => {
      // Keep the default.
    });
    service.conversations.load(context).then(() => {
      this.render();
      this.sync();
      this.resumeGoal = this.lastKnownGoal();
      this.loaded = true;
      // A home tile can hand over a goal (and optionally the mic).
      setTimeout(() => {
        const pending: string = AppStorage.get<string>('hopa.pendingGoal') ?? '';
        if (pending.length > 0) {
          AppStorage.setOrCreate<string>('hopa.pendingGoal', '');
          this.draft = pending;
          this.send();
          return;
        }
        const listen: boolean = AppStorage.get<boolean>('hopa.autovoice') ?? false;
        if (listen) {
          AppStorage.setOrCreate<boolean>('hopa.autovoice', false);
          this.startVoice();
        }
      }, 350);
    });
    this.timer = setInterval(() => {
      if (!this.busy) {
        const pending: string = AppStorage.get<string>('hopa.pendingGoal') ?? '';
        if (pending.length > 0) {
          AppStorage.setOrCreate<string>('hopa.pendingGoal', '');
          this.draft = pending;
          this.send();
          return;
        }
      }
      if (!this.busy && service.conversations.version !== this.seenVersion) {
        this.render();
        this.sync();
      }
      if (this.busy) {
        const steps: string[] = service.runtime.lastSteps();
        if (steps.length !== this.liveSteps.length) {
          this.liveSteps = steps.slice();
          const latest: string = steps.length > 0 ? steps[steps.length - 1] : '';
          RunNotification.update(latest.length > 2 ? latest.substring(2) : latest).catch(() => {
            // Best effort.
          });
        }
      }
      if (this.messages.length === 0) {
        const goal: string = this.lastKnownGoal();
        if (goal !== this.resumeGoal) {
          this.resumeGoal = goal;
        }
      }
    }, 500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.reactionTimer >= 0) {
      clearTimeout(this.reactionTimer);
      this.reactionTimer = -1;
    }
    if (this.recording) {
      this.recording = false;
      this.voice.cancel();
    }
    this.voice.release();
  }

  private sync(): void {
    this.seenVersion = AgentService.get().conversations.version;
  }

  private render(): void {
    const next: ResourceStr[] = [];
    const entries = AgentService.get().conversations.entries();
    // Long conversations keep the newest window; the rest stay in History.
    const start: number = entries.length > 300 ? entries.length - 300 : 0;
    this.trimmedCount = start;
    for (let index = start; index < entries.length; index++) {
      const entry = entries[index];
      next.push(entry.role === 'user' ? `You: ${entry.text}` : `HOPA: ${entry.text}`);
    }
    const grew: boolean = next.length > this.renderedCount;
    this.renderedCount = next.length;
    this.messages = next;
    if (grew) {
      this.scrollToEnd();
    }
  }

  /** Keeps the newest reply visible, including after a run returns to Chat. */
  private scrollToEnd(): void {
    setTimeout(() => {
      try {
        this.listScroller.scrollEdge(Edge.Bottom);
      } catch (error) {
        // The list is not mounted yet; the next render scrolls again.
      }
    }, 50);
  }

  private messageKey(item: ResourceStr, index: number): string {
    const live: string = !this.isUser(item) && index === this.lastAnswerIndex() ? '-live' : '';
    if (typeof item === 'string') {
      return `${index}-${item}${live}`;
    }
    return `${index}-resource${live}`;
  }

  private textOf(item: ResourceStr): string {
    return ChatFormat.textOf(item);
  }

  private lastAnswerIndex(): number {
    for (let index = this.messages.length - 1; index >= 0; index--) {
      const item: ResourceStr = this.messages[index];
      if (typeof item === 'string' && item.startsWith('HOPA: ')) {
        return index;
      }
    }
    return -1;
  }

  private lastUserIndex(): number {
    for (let index = this.messages.length - 1; index >= 0; index--) {
      const item: ResourceStr = this.messages[index];
      if (typeof item === 'string' && item.startsWith('You: ')) {
        return index;
      }
    }
    return -1;
  }

  private lastUserText(): string {
    const index: number = this.lastUserIndex();
    if (index < 0) {
      return '';
    }
    const item: ResourceStr = this.messages[index];
    return typeof item === 'string' ? item.substring(5) : '';
  }

  private retry(): void {
    const text: string = this.lastUserText();
    if (text.length === 0 || this.busy) {
      return;
    }
    this.draft = text;
    this.send();
  }

  /** Copy one message to the system clipboard. */
  private copy(text: string): void {
    if (text.length === 0) {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.getUIContext().getPromptAction().showToast({ message: 'Copied' });
      }).catch(() => {
        // The clipboard may be unavailable; long-press still allows selection.
      });
    } catch (error) {
      // Copy is best effort.
    }
  }

  private lastRunVerified(): boolean {
    const runs = AgentService.get().runs.all();
    return runs.length > 0 && runs[runs.length - 1].verified;
  }

  /** First http(s) link in an answer, or ''. */
  private firstUrl(text: string): string {
    const match = text.match(/https?:\/\/[^\s)]+/);
    return match === null ? '' : match[0];
  }

  private isUser(item: ResourceStr): boolean {
    return ChatFormat.isUser(item);
  }

  /** One marker line at the top of a stored answer: steps and screenshot. */
  private metaLine(item: ResourceStr): string {
    return ChatFormat.metaLine(item);
  }

  private metaValue(item: ResourceStr, key: string): string {
    return ChatFormat.metaValue(item, key);
  }

  private stepsOf(item: ResourceStr): string[] {
    return ChatFormat.stepsOf(item);
  }

  /** Green for success, coral for a failed step. */
  private stepColor(step: string): ResourceColor {
    return step.startsWith('✓') ? $r('app.color.success') : $r('app.color.danger');
  }

  /** Numbered items of an answer; empty when the text is prose. */
  private listItems(text: string): string[] {
    return ChatFormat.listItems(text);
  }

  /** A short sentence that introduces the list, when the model wrote one. */
  private listLead(text: string): string {
    return ChatFormat.listLead(text);
  }

  private shotOf(item: ResourceStr): string {
    return ChatFormat.shotOf(item);
  }

  private bubbleText(item: ResourceStr): ResourceStr {
    return ChatFormat.bubbleText(item);
  }

  /** Hide raw tool-call markup a model may leak into its answer. */
  private stripToolMarkup(text: string): string {
    return ChatFormat.stripToolMarkup(text);
  }

  /** Chat bubbles are plain text; strip the Markdown a model may add. */
  private plainAnswer(text: string): string {
    return ChatFormat.plainAnswer(text);
  }

  /** The most recent goal, from this session or from the saved chats. */
  private lastKnownGoal(): string {
    const service = AgentService.get();
    const live: string = service.runtime.lastGoalText();
    if (live.length > 0) {
      this.resumeAt = Date.now();
      return live;
    }
    const sessions = service.conversations.all();
    let best: number = -1;
    let goal: string = '';
    for (let i = 0; i < sessions.length; i++) {
      const session = sessions[i];
      if (session.updatedAt < best) {
        continue;
      }
      for (let j = session.entries.length - 1; j >= 0; j--) {
        const entry = session.entries[j];
        if (entry.role === 'user' && entry.text.length > 0) {
          best = session.updatedAt;
          this.resumeAt = session.updatedAt;
          goal = entry.text;
          break;
        }
      }
    }
    return goal;
  }

  private profile(): ModeProfile {
    return ModeProfile.of(this.profileName);
  }

  private style(): VisualStyle {
    return VisualStyle.of(this.styleName);
  }

  /** Kid mode refuses money and public posting before the model sees it. */
  private guardianBlocked(text: string): boolean {
    return /(^|\s)(pay|buy|order|checkout|transfer|tweet|post|publish|subscribe)(\s|$)|send money|weibo|instagram|tiktok|facebook/i.test(text);
  }

  private hasEarlierChat(): boolean {
    const service = AgentService.get();
    const currentId: string = service.conversations.currentId();
    for (const session of service.conversations.all()) {
      if (session.id !== currentId && session.entries.length > 0) {
        return true;
      }
    }
    return false;
  }

  /** Bring back the most recently touched conversation, not a new prompt. */
  private openLastChat(): void {
    const service = AgentService.get();
    const currentId: string = service.conversations.currentId();
    let bestId: string = '';
    let bestAt: number = -1;
    for (const session of service.conversations.all()) {
      if (session.id === currentId || session.entries.length === 0) {
        continue;
      }
      if (session.updatedAt > bestAt) {
        bestAt = session.updatedAt;
        bestId = session.id;
      }
    }
    if (bestId.length === 0) {
      this.draft = this.resumeGoal;
      return;
    }
    service.conversations.select(bestId);
    this.render();
    this.sync();
    this.resumeGoal = '';
    this.draft = '';
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim();
    if (text.length === 0 || this.busy) {
      return;
    }
    const service = AgentService.get();
    const context = getContext(this) as Context;
    if (this.profile().guardian && this.guardianBlocked(text)) {
      this.messages = this.messages.concat([
        `You: ${text}`,
        'HOPA: This phone is in Kid mode, so I can\'t buy things or post publicly. A grown-up can switch profiles in Settings.'
      ]);
      service.conversations.add('user', text);
      service.conversations.add('assistant', 'Kid mode: payments and public posts are off.');
      this.sync();
      this.draft = '';
      return;
    }
    const fact: string | undefined = MemoryExtractor.extract(text);
    if (fact !== undefined && service.memory.add(fact) !== undefined) {
      service.memory.save(context).catch(() => {
        // Persistence is best effort; memory still works in this session.
      });
    }
    if (!service.hasModel()) {
      this.messages = this.messages.concat([
        `You: ${text}`,
        $r('app.string.msg_no_model')
      ]);
      service.conversations.add('user', text);
      service.conversations.add('assistant', 'No model configured.');
      AppStorage.setOrCreate<string>('hopa.problem', 'Model not configured');
      this.sync();
      this.draft = '';
      return;
    }

    this.draft = '';
    this.busy = true;
    RunNotification.start(getContext(this) as common.UIAbilityContext, text).catch(() => {
      // Notifications are optional.
    });
    this.reaction = '';
    this.characterLine = '';
    this.liveSteps = [];
    this.runningGoal = text;
    Haptics.tap();
    this.messages = this.messages.concat([`You: ${text}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('user', text);
    this.sync();

    const beforeTitle: string = service.pageLinks.title();
    const beforeUrl: string = service.pageLinks.url();
    const reply: string = await service.run(text);
    const afterTitle: string = service.pageLinks.title();
    const afterUrl: string = service.pageLinks.url();
    this.diffText = afterUrl !== beforeUrl
      ? `${beforeTitle.length > 0 ? beforeTitle : 'Page'} \u2192 ${afterTitle.length > 0 ? afterTitle : afterUrl}`
      : '';
    const low: string = reply.toLowerCase();
    this.failed = low.includes("couldn't") || low.includes('failed') || low.includes('error');
    const steps: string[] = service.runtime.lastSteps();
    let shotPath: string = '';
    // Only keep a screenshot when the run touched another app. A text answer
    // would otherwise show HOPA's own chat under "What HOPA saw".
    if (!AppFocus.active && service.lastRunHadActions() && service.isBridgeConfigured()) {
      const foreground: string = await service.bridge.foregroundBundle();
      if (foreground.length > 0 && foreground !== 'com.hopa.agent') {
        const shot: string = await service.bridge.screenshot();
        const marker: number = shot.indexOf('base64,');
        if (marker > 0) {
          try {
            const helper: util.Base64Helper = new util.Base64Helper();
            const bytes: Uint8Array = helper.decodeSync(shot.substring(marker + 7));
            shotPath = `${context.filesDir}/shot-${Date.now()}.jpg`;
            const file = fs.openSync(shotPath, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
            const buffer: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
            fs.writeSync(file.fd, buffer);
            fs.closeSync(file);
          } catch (error) {
            shotPath = '';
            hilog.warn(0x0000, 'HOPA', `shot save failed: ${error}`);
          }
        }
      }
    }
    this.undoSteps = steps.slice();
    const meta: string[] = [];
    if (steps.length > 0) {
      meta.push(`steps=${steps.join(' | ')}`);
    }
    if (shotPath.length > 0) {
      meta.push(`shot=${shotPath}`);
    }
    const shown: string = this.failed ? Character.failure(reply, this.profileName) : reply;
    this.characterLine = Character.quip(!this.failed, steps.length, this.profileName);
    const decorated: string = meta.length > 0
      ? `\u27e6meta\u27e7${meta.join(';')}\n${shown}`
      : shown;
    this.messages = this.messages.concat([`HOPA: ${decorated}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('assistant', decorated);
    this.sync();
    this.busy = false;
    RunNotification.stop().catch(() => {
      // Best effort.
    });
    this.runningGoal = '';
    AppStorage.setOrCreate<string>('hopa.problem', this.failed ? 'Last run failed' : '');
    this.react(!this.failed);
    this.canUndo = steps.length === 1 &&
      (steps[0].indexOf('Opened') > 0 || steps[0].indexOf('Tapped') > 0);
    if (this.failed) {
      this.draft = text;
      ErrorLog.record(context, reply).catch(() => {
        // The log is best effort.
      });
    }
    if (this.speakReplies && !this.failed) {
      this.speakReply(reply);
    }
    service.skills.save(context).catch(() => {
      // Persistence is best effort.
    });
  }

  private stopRun(): void {
    AgentService.get().cancel();
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private async startVoice(): Promise<void> {
    if (this.busy || this.recording) {
      return;
    }
    const allowed: boolean = await this.voice.start(getContext(this) as common.UIAbilityContext);
    if (!allowed) {
      this.toast('Microphone permission is needed for voice.');
      return;
    }
    this.recording = true;
    Haptics.tap();
  }

  private async stopVoice(): Promise<void> {
    if (!this.recording) {
      return;
    }
    this.recording = false;
    const heard: string = await this.voice.stop();
    if (heard.length === 0) {
      this.toast("Didn't catch that — tap and try again.");
      return;
    }
    this.draft = heard;
    Haptics.tap();
  }

  /** The request that produced the last answer. */
  private lastUserGoal(): string {
    const index: number = this.lastAnswerIndex();
    for (let cursor = index - 1; cursor >= 0; cursor--) {
      const item: ResourceStr = this.messages[cursor];
      if (typeof item === 'string' && item.startsWith('You: ')) {
        return item.substring(5);
      }
    }
    return this.resumeGoal;
  }

  private async shareRecap(): Promise<void> {
    const index: number = this.lastAnswerIndex();
    if (index < 0) {
      return;
    }
    this.recapGoal = this.lastUserGoal();
    this.recapAnswer = this.textOf(this.messages[index]);
    this.recapSteps = this.stepsOf(this.messages[index]);
    try {
      // One frame so the hidden card is laid out before it is captured.
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 80));
      const snapshot = await this.getUIContext().getComponentSnapshot().createFromBuilder(() => {
        RecapCard({ goal: this.recapGoal, answer: this.recapAnswer, steps: this.recapSteps });
      });
      const packer: image.ImagePacker = image.createImagePacker();
      const png: ArrayBuffer = await packer.packing(snapshot, { format: 'image/png', quality: 92 });
      const shared: boolean = await this.shareRecapImage(png);
      if (!shared) {
        this.toast('Could not open the share sheet.');
      }
    } catch (error) {
      this.toast('Could not build the recap image.');
    }
  }

  /** Share one answer as a plain text file; no album permission needed. */
  private async shareResult(text: string): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const path: string = `${context.cacheDir}/hopa-result-${Date.now()}.txt`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(file.fd, text);
      } finally {
        fs.closeSync(file);
      }
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'text/plain',
        uri: fileUri.getUriFromPath(path),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await context.startAbility(want);
    } catch (error) {
      this.toast('Could not open the share sheet.');
    }
  }

  /** Keep one answer as a memory fact the user can see and delete. */
  private async rememberResult(text: string): Promise<void> {
    const service = AgentService.get();
    const item = service.memory.add(text);
    if (item === undefined) {
      return;
    }
    await service.memory.save(getContext(this) as common.UIAbilityContext);
    this.toast('Remembered');
  }

  /** Hand the PNG to the system share sheet; no album permission needed. */
  private async shareRecapImage(png: ArrayBuffer): Promise<boolean> {
    const context = getContext(this) as common.UIAbilityContext;
    try {
      const path: string = `${context.cacheDir}/hopa-recap-${Date.now()}.png`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      try {
        fs.writeSync(file.fd, png);
      } finally {
        fs.closeSync(file);
      }
      const want: Want = {
        action: 'ohos.want.action.sendData',
        type: 'image/png',
        uri: fileUri.getUriFromPath(path),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      };
      await context.startAbility(want);
      return true;
    } catch (error) {
      return false;
    }
  }

  /** No-ACL path: put the answer on the clipboard, then open the app. */
  private async copyAndOpen(): Promise<void> {
    const index: number = this.lastAnswerIndex();
    if (index < 0) {
      return;
    }
    const answer: string = this.textOf(this.messages[index]);
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, answer);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (error) {
      this.toast('Could not copy to the clipboard.');
      return;
    }
    const bundle: string = this.lastOpenedBundle();
    const service = AgentService.get();
    if (bundle.length > 0 && service.isBridgeConfigured()) {
      service.bridge.launch(bundle);
      this.toast('Copied — paste it in the app.');
    } else {
      this.toast('Copied to the clipboard.');
    }
  }

  private lastOpenedBundle(): string {
    const runs = AgentService.get().runs.all();
    for (let index = runs.length - 1; index >= 0; index--) {
      const run = runs[index];
      if (run.kind !== 'ui.launch' || run.detail.length === 0) {
        continue;
      }
      let name: string = run.detail.startsWith('Opened ') ? run.detail.substring(7) : run.detail;
      if (name.endsWith('.')) {
        name = name.substring(0, name.length - 1);
      }
      for (const app of APP_CATALOG) {
        if (app.display === name || app.name === name) {
          return app.bundle;
        }
      }
    }
    return '';
  }

  private async speakReply(text: string): Promise<void> {
    await this.voice.speak(text, getContext(this) as common.UIAbilityContext);
  }

  /** One small, earned reaction after a run: a hop or a softer face. */
  private react(ok: boolean): void {
    this.reaction = ok ? 'happy' : 'error';
    if (ok) {
      Haptics.success();
    } else {
      Haptics.error();
    }
    if (this.reactionTimer >= 0) {
      clearTimeout(this.reactionTimer);
    }
    this.reactionTimer = setTimeout(() => {
      this.reaction = '';
      this.reactionTimer = -1;
    }, 2200);
  }

  build() {
    Column({ space: 10 }) {
      if (!this.loaded) {
        Column({ space: 12 }) {
          ForEach([0, 1, 2], (item: number) => {
            Row() {
              Column()
                .width('68%')
                .height(38)
                .borderRadius(14)
                .backgroundColor($r('app.color.surface_alt'))
                .opacity(0.7 - item * 0.15)
                .margin({ left: item % 2 === 0 ? 0 : 18 })
            }
            .width('100%')
            .justifyContent(item % 2 === 0 ? FlexAlign.Start : FlexAlign.End)
          }, (item: number) => `${item}`)
        }
        .width('100%')
        .padding({ top: 24, left: 16, right: 16 })
        .layoutWeight(1)
      } else if (this.messages.length === 0) {
        Scroll() {
          ChatEmptyState({
            resume: this.resumeGoal,
            resumeAt: this.resumeAt,
            hasEarlier: this.hasEarlierChat(),
            listening: this.draft.length > 0,
            onPick: (text: string) => {
              this.draft = text;
            },
            onResume: () => {
              this.openLastChat();
            },
            onTrust: () => {
              AppStorage.setOrCreate<boolean>('hopa.openPermissions', true);
              AppStorage.setOrCreate<string>('hopa.goto', 'settings');
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .clip(true)
      } else {
        List({ space: this.profile().density === 'compact' ? 6 : 10, scroller: this.listScroller }) {
          if (this.trimmedCount > 0) {
            ListItem() {
              Text(`${this.trimmedCount} earlier messages stay in History.`)
                .fontSize(10.5)
                .fontColor($r('app.color.text_hint'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 6 })
            }
          }
          ForEach(this.messages, (item: ResourceStr, index: number) => {
            ListItem() {
              Row() {
                if (this.isUser(item)) {
                  Column({ space: 2 }) {
                    Text(this.bubbleText(item))
                      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                      .backgroundColor($r('app.color.primary'))
                      .fontColor($r('app.color.on_primary'))
                      .borderRadius(this.style().bubbleRadius)
                      .fontSize(this.style().body)
                      .constraintSize({ maxWidth: '84%' })
                      .copyOption(CopyOptions.LocalDevice)
                    if (index === this.lastUserIndex() && !this.busy) {
                      MessageActions({
                        showRetry: true,
                        onCopy: () => {
                          this.copy(this.textOf(item));
                        },
                        onRetry: () => {
                          this.retry();
                        }
                      })
                      .padding({ right: 4 })
                    }
                  }
                  .alignItems(HorizontalAlign.End)
                } else {
                  Row({ space: 8 }) {
                    if (index === this.lastAnswerIndex()) {
                      HopaMark({
                        state: this.reaction.length > 0 ? this.reaction : 'idle',
                        markSize: 26
                      })
                        .margin({ top: 4 })
                    } else {
                      // Keep the text column aligned without repeating the
                      // character on every answer.
                      Row().width(26).height(1)
                    }
                    Column({ space: 4 }) {
                      if (this.showSteps && this.stepsOf(item).length > 0) {
                        Flex({ wrap: FlexWrap.Wrap }) {
                          ForEach(this.stepsOf(item), (step: string) => {
                            Row({ space: 5 }) {
                              Circle({ width: 4, height: 4 })
                                .fill(this.stepColor(step))
                              Text(step.substring(2))
                                .fontSize(11)
                                .fontColor($r('app.color.text_secondary'))
                            }
                            .padding({ left: 8, right: 9, top: 3, bottom: 3 })
                            .backgroundColor($r('app.color.surface_alt'))
                            .borderRadius(9)
                            .margin({ right: 6, bottom: 4 })
                          }, (step: string, i: number) => `${i}-${step}`)
                        }
                        .width('100%')
                      }
                      if (this.listItems(this.textOf(item)).length > 0) {
                        Column({ space: 8 }) {
                          if (this.listLead(this.textOf(item)).length > 0) {
                            Text(this.listLead(this.textOf(item)))
                              .fontSize(14)
                              .fontColor($r('app.color.text_primary'))
                              .width('100%')
                          }
                          ForEach(this.listItems(this.textOf(item)), (line: string, i: number) => {
                            Row({ space: 10 }) {
                              Text(`${i + 1}`)
                                .fontSize(10)
                                .fontWeight(FontWeight.Bold)
                                .fontColor($r('app.color.primary'))
                                .width(20)
                                .height(20)
                                .textAlign(TextAlign.Center)
                                .backgroundColor($r('app.color.primary_soft'))
                                .borderRadius(10)
                              Text(line)
                                .fontSize(13.5)
                                .lineHeight(20)
                                .fontColor($r('app.color.text_primary'))
                                .layoutWeight(1)
                                .copyOption(CopyOptions.LocalDevice)
                            }
                            .width('100%')
                            .alignItems(VerticalAlign.Top)
                          }, (line: string, i: number) => `${i}-${line}`)
                        }
                        .width('100%')
                        .padding({ top: 2, bottom: 2 })
                      } else {
                        Text(this.bubbleText(item))
                          .width('100%')
                          .fontSize(this.style().body)
                          .lineHeight(this.style().body + 7)
                          .fontColor($r('app.color.text_primary'))
                          .padding({ left: 2, right: 2, top: 2, bottom: 2 })
                          .copyOption(CopyOptions.LocalDevice)
                      }
                      if (index === this.lastAnswerIndex() && !this.busy &&
                        this.characterLine.length > 0) {
                        Text(this.characterLine)
                          .fontSize(10.5)
                          .fontColor($r('app.color.text_hint'))
                          .width('100%')
                          .padding({ left: 2, top: 2 })
                      }
                      if (index === this.lastAnswerIndex() && !this.busy &&
                        AgentService.get().lastRunHadActions()) {
                        Row({ space: 5 }) {
                          Circle({ width: 5, height: 5 })
                            .fill(this.lastRunVerified()
                              ? $r('app.color.success')
                              : $r('app.color.warning'))
                          Text(this.lastRunVerified()
                            ? 'Verified on screen'
                            : 'Not verified on screen')
                            .fontSize(9.5)
                            .fontColor($r('app.color.text_hint'))
                        }
                        .width('100%')
                        .padding({ left: 2, top: 1, bottom: 2 })
                      }
                      if (!this.busy && this.shotOf(item).length > 0) {
                        Row({ space: 10 }) {
                          Image('file://' + this.shotOf(item))
                            .width(54)
                            .height(96)
                            .objectFit(ImageFit.Cover)
                            .borderRadius(8)
                            .border({ width: 1, color: '#141C1B18' })
                          Column({ space: 2 }) {
                            Text('What HOPA saw')
                              .fontSize(10.5)
                              .fontColor($r('app.color.text_secondary'))
                            Text('The last screen it read before answering.')
                              .fontSize(9.5)
                              .fontColor($r('app.color.text_hint'))
                              .maxLines(2)
                          }
                          .layoutWeight(1)
                          .alignItems(HorizontalAlign.Start)
                        }
                        .width('100%')
                        .padding(8)
                        .backgroundColor($r('app.color.surface_alt'))
                        .borderRadius(10)
                      }
                      if (index === this.lastAnswerIndex() && !this.busy && this.diffText.length > 0) {
                        Row({ space: 6 }) {
                          Text('Changed')
                            .fontSize(9)
                            .fontWeight(FontWeight.Bold)
                            .fontColor($r('app.color.primary'))
                            .letterSpacing(0.5)
                          Text(this.diffText)
                            .fontSize(10.5)
                            .fontColor($r('app.color.text_secondary'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)
                        }
                        .width('100%')
                        .padding(8)
                        .backgroundColor($r('app.color.surface_alt'))
                        .borderRadius(8)
                      }
                      if (index === this.lastAnswerIndex() && !this.busy && this.canUndo) {
                        Row() {
                          Text('Undo')
                            .fontSize(11)
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('app.color.primary'))
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor($r('app.color.primary_soft'))
                            .borderRadius(8)
                            .onClick(() => {
                              const typed: number = AgentService.get().runtime.typedLength();
                              if (typed > 0) {
                                AgentService.get().bridge.key('Backspace', typed);
                                this.canUndo = false;
                                this.getUIContext().getPromptAction().showToast({
                                  message: typed === 1 ? 'Removed 1 character' : `Removed ${typed} characters`
                                });
                                return;
                              }
                              const undoKey: string = this.undoSteps.length > 0 && this.undoSteps[0].indexOf('Tapped') > 0
                                ? 'Back'
                                : 'Home';
                              AgentService.get().bridge.key(undoKey);
                              this.canUndo = false;
                              this.getUIContext().getPromptAction().showToast({
                                message: undoKey === 'Back' ? 'Went back one screen' : 'Back to the home screen'
                              });
                            })
                        }
                        .width('100%')
                      }
                      if (index === this.lastAnswerIndex() && !this.busy && !this.failed &&
                        this.profile().sharing !== 'minimal') {
                        Row({ space: 6 }) {
                          if (this.profile().sharing === 'recap') {
                            Text('Share recap')
                              .fontSize(10.5)
                              .fontColor($r('app.color.text_secondary'))
                              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                              .backgroundColor($r('app.color.surface_alt'))
                              .borderRadius(8)
                              .onClick(() => {
                                this.shareRecap();
                              })
                          }
                        }
                        .width('100%')
                      }
                      if (index === this.lastAnswerIndex() && !this.busy && this.failed) {
                        Row({ space: 8 }) {
                          Text('That did not work.')
                            .fontSize(11)
                            .fontColor($r('app.color.danger'))
                            .layoutWeight(1)
                          Text('Try again')
                            .fontSize(11)
                            .fontWeight(FontWeight.Medium)
                            .fontColor($r('app.color.primary'))
                            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                            .backgroundColor($r('app.color.primary_soft'))
                            .borderRadius(8)
                            .onClick(() => {
                              this.retry();
                            })
                        }
                        .width('100%')
                        .padding(8)
                        .backgroundColor('#0FD9342F')
                        .borderRadius(10)
                      }
                      if (index === this.lastAnswerIndex() && !this.busy) {
                        ResultActions({
                          showOpen: this.firstUrl(this.textOf(item)).length > 0,
                          onOpen: () => {
                            AgentService.get().pageLinks.open(this.firstUrl(this.textOf(item)));
                          },
                          onCopy: () => {
                            this.copy(this.textOf(item));
                          },
                          onShare: () => {
                            this.shareResult(this.textOf(item));
                          },
                          onRemember: () => {
                            this.rememberResult(this.textOf(item));
                          }
                        })
                      }
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Top)
                }
              }
              .width('100%')
              .justifyContent(this.isUser(item) ? FlexAlign.End : FlexAlign.Start)
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 })).animation({ duration: 220, curve: Curve.EaseOut }))
            }
          }, (item: ResourceStr, index: number) => this.messageKey(item, index))
          if (this.busy) {
            ListItem() {
              Column({ space: 4 }) {
                if (this.runningGoal.length > 0) {
                  Row({ space: 6 }) {
                    Text(`Working on ${this.runningGoal}`)
                      .fontSize(11)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                    Text('Cancel')
                      .fontSize(11)
                      .fontColor($r('app.color.primary'))
                      .padding({ left: 8, right: 4, top: 2, bottom: 2 })
                      .onClick(() => {
                        this.stopRun();
                      })
                  }
                  .width('100%')
                  .padding({ left: 4 })
                }
                if (this.liveSteps.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.liveSteps, (step: string) => {
                      Row({ space: 5 }) {
                        Circle({ width: 4, height: 4 })
                          .fill(this.stepColor(step))
                        Text(step.substring(2))
                          .fontSize(10.5)
                          .fontColor($r('app.color.text_secondary'))
                      }
                      .padding({ left: 8, right: 9, top: 3, bottom: 3 })
                      .backgroundColor($r('app.color.surface_alt'))
                      .borderRadius(8)
                      .margin({ right: 6, bottom: 4 })
                    }, (step: string, i: number) => `${i}-${step}`)
                  }
                  .width('100%')
                  .padding({ left: 4 })
                }
                if (this.liveSteps.length > 0) {
                  Text(Character.narrate(this.liveSteps[this.liveSteps.length - 1].substring(2)))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .padding({ left: 4, bottom: 2 })
                }
                ChatTyping()
              }
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .onAreaChange((_old: Area, now: Area) => {
          // The keyboard shrinking the list must not leave the newest message
          // off-screen; re-anchor to the end whenever the height changes.
          if (String(now.height) !== String(_old.height)) {
            this.scrollToEnd();
          }
        })
      }
      if (this.lastPageUrl.length > 0) {
        ChatPageCard({
          title: this.lastPageTitle,
          url: this.lastPageUrl,
          onOpen: () => {
            AgentService.get().pageLinks.open(this.lastPageUrl);
          }
        })
      }
      ChatComposer({
        draft: this.draft,
        busy: this.busy,
        recording: this.recording,
        onDraft: (value: string) => {
          this.draft = value;
        },
        onSend: () => {
          this.send();
        },
        onStop: () => {
          this.stopRun();
        },
        onVoiceStart: () => {
          this.startVoice();
        },
        onVoiceStop: () => {
          this.stopVoice();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }
}