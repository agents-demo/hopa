import { Context } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { SettingsStore } from '../../services/SettingsStore';
import { ChatEmptyState } from './ChatEmptyState';
import { ChatPageCard } from './ChatPageCard';
import { ChatComposer } from './ChatComposer';
import { ChatTyping } from './ChatTyping';
import { MessageActions } from './MessageActions';
import { HopaMark } from './HopaMark';
import { Haptics } from '../../services/Haptics';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** Chat: the transcript, the empty state and the composer. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State reaction: string = '';
  @State resumeGoal: string = '';
  @State runningGoal: string = '';
  @State failed: boolean = false;
  @State liveSteps: string[] = [];
  @State showSteps: boolean = true;
  @State lastPageUrl: string = '';
  @State lastPageTitle: string = '';
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
    }).catch(() => {
      // Keep the default.
    });
    service.conversations.load(context).then(() => {
      this.render();
      this.sync();
      this.resumeGoal = this.lastKnownGoal();
    });
    this.timer = setInterval(() => {
      if (!this.busy && service.conversations.version !== this.seenVersion) {
        this.render();
        this.sync();
      }
      if (this.busy) {
        const steps: string[] = service.runtime.lastSteps();
        if (steps.length !== this.liveSteps.length) {
          this.liveSteps = steps.slice();
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
  }

  private sync(): void {
    this.seenVersion = AgentService.get().conversations.version;
  }

  private render(): void {
    const next: ResourceStr[] = [];
    for (const entry of AgentService.get().conversations.entries()) {
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
    const text: ResourceStr = this.bubbleText(item);
    return typeof text === 'string' ? text : '';
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

  private isUser(item: ResourceStr): boolean {
    return typeof item === 'string' && item.startsWith('You: ');
  }

  /** One marker line at the top of a stored answer: steps and screenshot. */
  private metaLine(item: ResourceStr): string {
    if (typeof item !== 'string') {
      return '';
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6meta\u27e7') !== 0) {
      return '';
    }
    const end: number = body.indexOf('\n');
    return end < 0 ? body : body.substring(0, end);
  }

  private metaValue(item: ResourceStr, key: string): string {
    const line: string = this.metaLine(item);
    if (line.length === 0) {
      return '';
    }
    for (const part of line.substring('\u27e6meta\u27e7'.length).split(';')) {
      if (part.startsWith(`${key}=`)) {
        return part.substring(key.length + 1);
      }
    }
    return '';
  }

  private stepsOf(item: ResourceStr): string[] {
    const list: string = this.metaValue(item, 'steps');
    return list.length === 0 ? [] : list.split(' | ');
  }

  /** Green for success, coral for a failed step. */
  private stepColor(step: string): ResourceColor {
    return step.startsWith('✓') ? $r('app.color.success') : $r('app.color.danger');
  }

  /** Numbered items of an answer; empty when the text is prose. */
  private listItems(text: string): string[] {
    const items: string[] = [];
    for (const line of text.split('\n')) {
      const match = line.trim().match(/^\d+[.)]\s+(.*)$/);
      if (match !== null) {
        items.push(match[1]);
      }
    }
    return items.length >= 2 ? items : [];
  }

  /** A short sentence that introduces the list, when the model wrote one. */
  private listLead(text: string): string {
    for (const line of text.split('\n')) {
      const trimmed: string = line.trim();
      if (trimmed.length === 0) {
        continue;
      }
      if (trimmed.match(/^\d+[.)]\s+/) !== null) {
        return '';
      }
      return trimmed;
    }
    return '';
  }

  private shotOf(item: ResourceStr): string {
    return this.metaValue(item, 'shot');
  }

  private bubbleText(item: ResourceStr): ResourceStr {
    if (typeof item !== 'string') {
      return item;
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6meta\u27e7') === 0) {
      const end: number = body.indexOf('\n');
      return end < 0 ? '' : body.substring(end + 1);
    }
    if (item.startsWith('You: ')) {
      return item.substring(5);
    }
    if (item.startsWith('HOPA: ')) {
      return this.plainAnswer(item.substring(6));
    }
    return item;
  }

  /** Hide raw tool-call markup a model may leak into its answer. */
  private stripToolMarkup(text: string): string {
    const kept: string[] = [];
    for (const line of text.split('\n')) {
      if (/DSML|<\/?parameter|<\/?invoke|string="true"/i.test(line)) {
        continue;
      }
      kept.push(line);
    }
    let clean: string = kept.join('\n');
    clean = clean.replace(/<\|\s*[\s\S]*?\s*\|>/g, '');
    clean = clean.replace(/<\/?\s*parameter[^>]*>/gi, '');
    clean = clean.replace(/<\/?\s*invoke[^>]*>/gi, '');
    return clean;
  }

  /** Chat bubbles are plain text; strip the Markdown a model may add. */
  private plainAnswer(text: string): string {
    let clean: string = this.stripToolMarkup(text);
    clean = clean.replace(/\*\*/g, '');
    clean = clean.replace(/__/g, '');
    clean = clean.replace(/`/g, '');
    clean = clean.replace(/^#{1,6}\s*/gm, '');
    clean = clean.replace(/^>\s?/gm, '');
    // A tool failure can echo raw shell output; keep the chat readable.
    clean = clean.replace(/\\n/g, '\n');
    const kept: string[] = [];
    for (const raw of clean.split('\n')) {
      kept.push(raw.length > 220 ? `${raw.substring(0, 220)}\u2026` : raw);
    }
    clean = kept.join('\n');
    if (clean.trim().length === 0) {
      return 'I hit a formatting error. Please try again.';
    }
    return clean.trim();
  }

  /** The most recent goal, from this session or from the saved chats. */
  private lastKnownGoal(): string {
    const service = AgentService.get();
    const live: string = service.runtime.lastGoalText();
    if (live.length > 0) {
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
          goal = entry.text;
          break;
        }
      }
    }
    return goal;
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim();
    if (text.length === 0 || this.busy) {
      return;
    }
    const service = AgentService.get();
    const context = getContext(this) as Context;
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
      this.sync();
      this.draft = '';
      return;
    }

    this.draft = '';
    this.busy = true;
    this.reaction = '';
    this.liveSteps = [];
    this.runningGoal = text;
    Haptics.tap();
    this.messages = this.messages.concat([`You: ${text}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('user', text);
    this.sync();

    const reply: string = await service.run(text);
    const low: string = reply.toLowerCase();
    this.failed = low.includes("couldn't") || low.includes('failed') || low.includes('error');
    let shotPath: string = '';
    if (service.isBridgeConfigured()) {
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
    const steps: string[] = service.runtime.lastSteps();
    const meta: string[] = [];
    if (steps.length > 0) {
      meta.push(`steps=${steps.join(' | ')}`);
    }
    if (shotPath.length > 0) {
      meta.push(`shot=${shotPath}`);
    }
    const decorated: string = meta.length > 0
      ? `\u27e6meta\u27e7${meta.join(';')}\n${reply}`
      : reply;
    this.messages = this.messages.concat([`HOPA: ${decorated}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('assistant', decorated);
    this.sync();
    this.busy = false;
    this.runningGoal = '';
    service.skills.save(context).catch(() => {
      // Persistence is best effort.
    });
  }

  private stopRun(): void {
    AgentService.get().cancel();
  }

  /** One small, earned reaction after a run: a hop or a softer face. */
  private react(ok: boolean): void {
    this.reaction = ok ? 'happy' : 'error';
    if (ok) {
      Haptics.tap();
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
      if (this.messages.length === 0) {
        Scroll() {
          ChatEmptyState({
            resume: this.resumeGoal,
            onPick: (text: string) => {
              this.draft = text;
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .clip(true)
      } else {
        List({ space: 10, scroller: this.listScroller }) {
          ForEach(this.messages, (item: ResourceStr, index: number) => {
            ListItem() {
              Row() {
                if (this.isUser(item)) {
                  Column({ space: 2 }) {
                    Text(this.bubbleText(item))
                      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                      .backgroundColor($r('app.color.primary'))
                      .fontColor($r('app.color.on_primary'))
                      .borderRadius(18)
                      .fontSize(15)
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
                    HopaMark({
                      state: this.reaction.length > 0 && index === this.lastAnswerIndex()
                        ? this.reaction
                        : 'idle',
                      markSize: 22,
                      animate: index === this.lastAnswerIndex()
                    })
                      .margin({ top: 4 })
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
                          .fontSize(15)
                          .lineHeight(22)
                          .fontColor($r('app.color.text_primary'))
                          .padding({ left: 2, right: 2, top: 2, bottom: 2 })
                          .copyOption(CopyOptions.LocalDevice)
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
                      if (index === this.lastAnswerIndex() && !this.busy && this.failed) {
                        Row({ space: 8 }) {
                          Text('Something went wrong.')
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
                        MessageActions({
                          showRetry: false,
                          muted: true,
                          onCopy: () => {
                            this.copy(this.textOf(item));
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
            }
          }, (item: ResourceStr, index: number) => this.messageKey(item, index))
          if (this.busy) {
            ListItem() {
              Column({ space: 4 }) {
                if (this.runningGoal.length > 0) {
                  Row({ space: 6 }) {
                    Text(`Working on ? ${this.runningGoal}`)
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
        onDraft: (value: string) => {
          this.draft = value;
        },
        onSend: () => {
          this.send();
        },
        onStop: () => {
          this.stopRun();
        }
      })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }
}