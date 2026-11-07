import { ChatSession } from '@hopa/core';

/** The left drawer: conversations, top-level pages and tools. */
@Component
export struct Drawer {
  @Prop activePage: string = 'chat';
  @Prop sessions: ChatSession[] = [];
  @Prop currentId: string = '';

  onNewChat: () => void = () => {};
  onSelect: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  onNavigate: (key: string) => void = () => {};

  @Builder
  Item(title: string, key: string) {
    Row() {
      Text(title)
        .fontSize(16)
        .fontColor(this.activePage === key ? '#0A59F7' : '#333333')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.activePage === key ? '#EAF1FF' : '#00000000')
    .borderRadius(8)
    .onClick(() => {
      this.onNavigate(key);
    })
  }

  build() {
    Column({ space: 6 }) {
      Text('HOPA')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 12, top: 8, bottom: 2 })
      Button('+ New chat')
        .fontSize(13)
        .height(34)
        .width('100%')
        .backgroundColor('#0A59F7')
        .onClick(() => {
          this.onNewChat();
        })
      Text('CONVERSATIONS')
        .fontSize(10)
        .fontColor('#999999')
        .padding({ left: 12, top: 4, bottom: 2 })
      ForEach(this.sessions, (session: ChatSession, index: number) => {
        Row({ space: 6 }) {
          Text(session.title)
            .fontSize(13)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('x')
            .fontSize(13)
            .fontColor('#B42318')
            .padding({ left: 8, right: 4 })
            .onClick(() => {
              this.onDelete(session.id);
            })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(session.id === this.currentId ? '#EAF1FF' : '#00000000')
        .onClick(() => {
          this.onSelect(session.id);
        })
      }, (session: ChatSession, index: number) => `${session.id}-${session.updatedAt}`)
      Divider()
        .margin({ top: 4, bottom: 4 })
      Column({ space: 1 }) {
        this.Item('Chat', 'chat')
        this.Item('Plans', 'plans')
        this.Item('Memory', 'memory')
        this.Item('Browser', 'browser')
        this.Item('Screens', 'screens')
        this.Item('Settings', 'settings')
        this.Item('About', 'about')
        this.Item('More', 'more')
        Divider()
          .margin({ top: 6, bottom: 6 })
        Text('TOOLS')
          .fontSize(10)
          .fontColor('#999999')
          .padding({ left: 12, bottom: 2 })
        this.Item('Apps', 'apps')
        this.Item('Runs and batches', 'runs')
        this.Item('Models', 'models')
        this.Item('Usage', 'usage')
        this.Item('Phone setup', 'phone')
        this.Item('Self-check', 'selfcheck')
        this.Item('Welcome', 'welcome')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
  }
}
