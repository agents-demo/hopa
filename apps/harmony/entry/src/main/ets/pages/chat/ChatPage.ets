import { Context } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';
import { ChatEmptyState } from './ChatEmptyState';
import { ChatPageCard } from './ChatPageCard';
import { HopaMark } from './HopaMark';

/** Chat: the transcript, the empty state and the composer. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State pulse: boolean = false;
  @State lastPageUrl: string = '';
  @State lastPageTitle: string = '';
  private seenVersion: number = -1;
  private timer: number = -1;
  private pulseTimer: number = -1;
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
    }, 500);
    this.pulseTimer = setInterval(() => {
      this.pulse = !this.pulse;
    }, 450);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
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
    if (typeof item === 'string') {
      return `${index}-${item}`;
    }
    return `${index}-resource`;
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

  private lastUserText(): string {
    for (let index = this.messages.length - 1; index >= 0; index--) {
      const item: ResourceStr = this.messages[index];
      if (typeof item === 'string' && item.startsWith('You: ')) {
        return item.substring(5);
      }
    }
    return '';
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

  private bubbleText(item: ResourceStr): ResourceStr {
    if (typeof item !== 'string') {
      return item;
    }
    if (item.startsWith('You: ')) {
      return item.substring(5);
    }
    if (item.startsWith('HOPA: ')) {
      return this.plainAnswer(item.substring(6));
    }
    return item;
  }

  /** Chat bubbles are plain text; strip the Markdown a model may add. */
  private plainAnswer(text: string): string {
    let clean: string = text.replace(/\*\*/g, '');
    clean = clean.replace(/__/g, '');
    clean = clean.replace(/`/g, '');
    clean = clean.replace(/^#{1,6}\s*/gm, '');
    clean = clean.replace(/^>\s?/gm, '');
    return clean;
  }

  private canSend(): boolean {
    return this.draft.trim().length > 0;
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
    this.messages = this.messages.concat([`You: ${text}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('user', text);
    this.sync();

    const reply: string = await service.run(text);
    this.lastPageUrl = service.pageLinks.url();
    this.lastPageTitle = service.pageLinks.title();

    this.messages = this.messages.concat([`HOPA: ${reply}`]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('assistant', reply);
    this.sync();
    this.busy = false;
    service.skills.save(context).catch(() => {
      // Persistence is best effort.
    });
  }

  private stopRun(): void {
    AgentService.get().cancel();
  }

  @Builder
  Typing() {
    Row({ space: 8 }) {
      HopaMark({ state: 'thinking', markSize: 24 })
      Row({ space: 4 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.pulse ? 1 : 0.3)
          .animation({ duration: 380, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.pulse ? 0.55 : 0.8)
          .animation({ duration: 380, curve: Curve.EaseInOut })
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.text_hint'))
          .opacity(this.pulse ? 0.3 : 1)
          .animation({ duration: 380, curve: Curve.EaseInOut })
      }
    }
    .width('100%')
    .padding({ left: 4, top: 10, bottom: 10 })
  }

  @Builder
  Composer() {
    Row({ space: 4 }) {
      TextInput({ placeholder: 'Ask HOPA...', text: this.draft })
        .layoutWeight(1)
        .height(42)
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .padding({ left: 8, right: 2 })
        .onChange((value: string) => {
          this.draft = value;
        })
        .onSubmit(() => {
          this.send();
        })
      Stack({ alignContent: Alignment.Center }) {
        if (this.busy) {
          Column()
            .width(11)
            .height(11)
            .borderRadius(2)
            .backgroundColor($r('app.color.on_primary'))
        } else {
          Text('↑')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.canSend()
              ? $r('app.color.on_primary')
              : $r('app.color.text_hint'))
        }
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.busy
        ? $r('app.color.danger')
        : (this.canSend() ? $r('app.color.primary') : $r('app.color.surface_muted')))
      .accessibilityText(this.busy ? 'Stop' : 'Send')
      .onClick(() => {
        if (this.busy) {
          this.stopRun();
        } else {
          this.send();
        }
      })
    }
    .width('100%')
    .padding({ left: 12, right: 4, top: 4, bottom: 4 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(26)
  }

  build() {
    Column({ space: 10 }) {
      if (this.messages.length === 0) {
        Column() {
          ChatEmptyState({
            onPick: (text: string) => {
              this.draft = text;
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 10, scroller: this.listScroller }) {
          ForEach(this.messages, (item: ResourceStr, index: number) => {
            ListItem() {
              Row() {
                if (this.isUser(item)) {
                  Text(this.bubbleText(item))
                    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                    .backgroundColor($r('app.color.primary'))
                    .fontColor($r('app.color.on_primary'))
                    .borderRadius(18)
                    .fontSize(15)
                    .constraintSize({ maxWidth: '84%' })
                    .copyOption(CopyOptions.LocalDevice)
                } else {
                  Column({ space: 2 }) {
                    Text(this.bubbleText(item))
                      .width('100%')
                      .fontSize(15)
                      .lineHeight(22)
                      .fontColor($r('app.color.text_primary'))
                      .padding({ left: 2, right: 2, top: 2, bottom: 2 })
                      .copyOption(CopyOptions.LocalDevice)
                    if (index === this.lastAnswerIndex() && !this.busy) {
                      Row({ space: 14 }) {
                        Text('Copy')
                          .fontSize(11)
                          .fontColor($r('app.color.primary'))
                          .padding({ top: 2, bottom: 2 })
                          .onClick(() => {
                            this.copy(this.textOf(item));
                          })
                        Text('Retry')
                          .fontSize(11)
                          .fontColor($r('app.color.primary'))
                          .padding({ top: 2, bottom: 2 })
                          .onClick(() => {
                            this.retry();
                          })
                      }
                      .padding({ left: 2 })
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .justifyContent(this.isUser(item) ? FlexAlign.End : FlexAlign.Start)
            }
          }, (item: ResourceStr, index: number) => this.messageKey(item, index))
          if (this.busy) {
            ListItem() {
              this.Typing()
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
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
      this.Composer()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }
}
