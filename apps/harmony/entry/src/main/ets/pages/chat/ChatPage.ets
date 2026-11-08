import { Context } from '@kit.AbilityKit';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';

/** Chat: the transcript, the composer and the approval dialog. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [
    $r('app.string.greeting_1'),
    $r('app.string.greeting_2')
  ];
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
    const next: ResourceStr[] = [
      $r('app.string.greeting_1'),
      $r('app.string.greeting_2')
    ];
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

  build() {
    Column({ space: 12 }) {
      List({ space: 8, scroller: this.listScroller }) {
        ForEach(this.messages, (item: ResourceStr, index: number) => {
          ListItem() {
            Row() {
              Text(this.bubbleText(item))
                .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                .backgroundColor(this.isUser(item) ? $r('app.color.primary') : $r('app.color.surface_muted'))
                .fontColor(this.isUser(item) ? $r('app.color.on_primary') : $r('app.color.text_primary'))
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
      if (this.lastPageUrl.length > 0) {
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
          Button('Open')
            .fontSize(12)
            .height(28)
            .backgroundColor($r('app.color.divider'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => {
              AgentService.get().pageLinks.open(this.lastPageUrl);
            })
        }
        .width('100%')
        .padding(8)
        .backgroundColor($r('app.color.primary_soft'))
        .borderRadius(8)
      }
      Row({ space: 8 }) {
        TextInput({ placeholder: 'Ask HOPA...', text: this.draft })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.draft = value;
          })
          .onSubmit(() => {
            this.send();
          })
        Button(this.busy ? $r('app.string.btn_stop') : $r('app.string.btn_send'))
          .backgroundColor(this.busy ? $r('app.color.danger') : $r('app.color.primary'))
          .onClick(() => {
            if (this.busy) {
              this.stopRun();
            } else {
              this.send();
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }
}
