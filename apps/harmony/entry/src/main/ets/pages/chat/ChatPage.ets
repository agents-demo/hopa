import { Context } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { ChatEmptyState } from './ChatEmptyState';
import { ChatPageCard } from './ChatPageCard';
import { ChatComposer } from './ChatComposer';
import { ChatTyping } from './ChatTyping';
import { MessageActions } from './MessageActions';
import { HopaMark } from './HopaMark';
import { Haptics } from '../../services/Haptics';

/** Chat: the transcript, the empty state and the composer. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State reaction: string = '';
  @State resumeGoal: string = '';
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
    service.conversations.load(context).then(() => {
      this.render();
      this.sync();
    });
    this.timer = setInterval(() => {
      if (!this.busy && service.conversations.version !== this.seenVersion) {
        this.render();
        this.sync();
      }
      if (this.messages.length === 0) {
        const goal: string = service.runtime.lastGoalText();
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

  /** Step labels embedded at the start of a stored answer, if any. */
  private stepsOf(item: ResourceStr): string[] {
    if (typeof item !== 'string') {
      return [];
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6steps\u27e7') !== 0) {
      return [];
    }
    const end: number = body.indexOf('\n');
    const head: string = end < 0 ? body : body.substring(0, end);
    const list: string = head.substring('\u27e6steps\u27e7'.length);
    if (list.length === 0) {
      return [];
    }
    return list.split(' | ');
  }

  private bubbleText(item: ResourceStr): ResourceStr {
    if (typeof item !== 'string') {
      return item;
    }
    const body: string = item.startsWith('HOPA: ') ? item.substring(6) : item;
    if (body.indexOf('\u27e6steps\u27e7') === 0) {
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
    if (clean.trim().length === 0) {
      return 'I hit a formatting error. Please try again.';
    }
    return clean.trim();
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
    this.messages = this.messages.concat([`You: ${text}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('user', text);
    this.sync();

    const reply: string = await service.run(text);
    this.lastPageUrl = service.pageLinks.url();
    this.lastPageTitle = service.pageLinks.title();
    if (service.lastRunHadActions()) {
      this.react(service.lastRunSucceeded());
    }

    const steps: string[] = service.runtime.lastSteps();
    const decorated: string = steps.length > 0
      ? `\u27e6steps\u27e7${steps.join(' | ')}\n${reply}`
      : reply;
    this.messages = this.messages.concat([`HOPA: ${decorated}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('assistant', decorated);
    this.sync();
    this.busy = false;
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
                      if (this.stepsOf(item).length > 0) {
                        Flex({ wrap: FlexWrap.Wrap }) {
                          ForEach(this.stepsOf(item), (step: string) => {
                            Text(step)
                              .fontSize(11)
                              .fontColor($r('app.color.text_secondary'))
                              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                              .backgroundColor($r('app.color.surface_alt'))
                              .borderRadius(9)
                              .margin({ right: 6, bottom: 4 })
                          }, (step: string, i: number) => `${i}-${step}`)
                        }
                        .width('100%')
                      }
                      Text(this.bubbleText(item))
                        .width('100%')
                        .fontSize(15)
                        .lineHeight(22)
                        .fontColor($r('app.color.text_primary'))
                        .padding({ left: 2, right: 2, top: 2, bottom: 2 })
                        .copyOption(CopyOptions.LocalDevice)
                      if (index === this.lastAnswerIndex() && !this.busy) {
                        MessageActions({
                          showRetry: false,
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
              ChatTyping()
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
