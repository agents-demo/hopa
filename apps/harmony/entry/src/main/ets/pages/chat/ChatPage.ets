import { Context } from '@kit.AbilityKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';

/** Chat: the transcript, the empty state and the composer. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State lastPageUrl: string = '';
  @State lastPageTitle: string = '';
  private seenVersion: number = -1;
  private timer: number = -1;
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
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
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

  private suggestions(): string[] {
    return [
      'Summarize the hottest Bilibili videos',
      'Open Settings and show me Wi-Fi',
      'Draft a one-line message to my team'
    ];
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
    this.messages = this.messages.concat([`You: ${text}`, $r('app.string.msg_working')]);
    this.renderedCount = this.messages.length;
    this.scrollToEnd();
    service.conversations.add('user', text);
    this.sync();

    const reply: string = await service.run(text);
    this.lastPageUrl = service.pageLinks.url();
    this.lastPageTitle = service.pageLinks.title();

    const next: ResourceStr[] = this.messages.slice(0, this.messages.length - 1);
    next.push(`HOPA: ${reply}`);
    this.messages = next;
    this.renderedCount = next.length;
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
  EmptyState() {
    Column({ space: 10 }) {
      Text('HOPA')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('Your phone agent. Ask for something on this phone.')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
      Text('I always ask before any payment.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Column({ space: 6 }) {
        ForEach(this.suggestions(), (suggestion: string) => {
          Row() {
            Text(suggestion)
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.divider') })
          .borderRadius(10)
          .onClick(() => {
            this.draft = suggestion;
          })
        }, (suggestion: string) => suggestion)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
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

  @Builder
  PageCard() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.lastPageTitle.length > 0 ? this.lastPageTitle : 'Page HOPA read')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.lastPageUrl)
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('Open')
        .fontSize(12)
        .fontColor($r('app.color.primary'))
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(8)
        .onClick(() => {
          AgentService.get().pageLinks.open(this.lastPageUrl);
        })
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.primary_soft'))
    .borderRadius(8)
  }

  build() {
    Column({ space: 10 }) {
      if (this.messages.length === 0) {
        this.EmptyState()
      } else {
        List({ space: 8, scroller: this.listScroller }) {
          ForEach(this.messages, (item: ResourceStr, index: number) => {
            ListItem() {
              Row() {
                Text(this.bubbleText(item))
                  .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                  .backgroundColor(this.isUser(item)
                    ? $r('app.color.primary')
                    : $r('app.color.surface_muted'))
                  .fontColor(this.isUser(item)
                    ? $r('app.color.on_primary')
                    : $r('app.color.text_primary'))
                  .borderRadius(16)
                  .fontSize(15)
                  .constraintSize({ maxWidth: '84%' })
              }
              .width('100%')
              .justifyContent(this.isUser(item) ? FlexAlign.End : FlexAlign.Start)
            }
          }, (item: ResourceStr, index: number) => this.messageKey(item, index))
        }
        .layoutWeight(1)
        .width('100%')
      }
      if (this.lastPageUrl.length > 0) {
        this.PageCard()
      }
      this.Composer()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }
}
