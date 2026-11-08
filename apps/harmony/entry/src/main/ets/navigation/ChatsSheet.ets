import { ChatSession } from '@hopa/core';
import { ChatSection, searchSessions, sectionsOf } from './ChatSections';
import { ToolEntry, ToolGroup, toolGroups } from './ToolCatalog';

/**
 * The Chats sheet: history and search, opened from the Chat title.
 *
 * It is not the main menu. Primary navigation lives in the bottom bar; this
 * sheet is only about conversations; Settings is a bottom-bar tab.
 */
@Component
export struct ChatsSheet {
  @Prop sessions: ChatSession[] = [];
  @Prop currentId: string = '';
  @State query: string = '';

  onNewChat: () => void = () => {};
  onSelect: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  onNavigate: (key: string) => void = () => {};

  private searching(): boolean {
    return this.query.trim().length > 0;
  }

  private visibleSections(): ChatSection[] {
    return sectionsOf(searchSessions(this.sessions, this.query), Date.now());
  }

  private hasChatMatch(): boolean {
    return searchSessions(this.sessions, this.query).length > 0;
  }

  private async confirmDelete(session: ChatSession): Promise<void> {
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: 'Delete this chat?',
        message: session.title.length > 0 ? session.title : 'New chat',
        buttons: [
          { text: 'Cancel', color: $r('app.color.text_secondary') },
          { text: 'Delete', color: $r('app.color.danger') }
        ]
      });
      if (result.index === 1) {
        this.onDelete(session.id);
      }
    } catch (error) {
      // A dialog that cannot open must not delete anything.
    }
  }

  @Builder
  ChatRow(session: ChatSession) {
    Row({ space: 6 }) {
      Text(session.title.length > 0 ? session.title : 'New chat')
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (session.id === this.currentId) {
        Text('Current')
          .fontSize(10)
          .fontColor($r('app.color.primary'))
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor(session.id === this.currentId ? $r('app.color.primary_soft') : $r('app.color.surface'))
    .onClick(() => {
      this.query = '';
      this.onSelect(session.id);
    })
  }

  @Builder
  DeleteAction(session: ChatSession) {
    Row() {
      Text('Delete')
        .fontSize(13)
        .fontColor($r('app.color.on_primary'))
    }
    .width(76)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.danger'))
    .borderRadius(10)
    .onClick(() => {
      this.confirmDelete(session);
    })
  }

  @Builder
  ToolRow(entry: ToolEntry) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(entry.title)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
        Text(entry.subtitle)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(16)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.query = '';
      this.onNavigate(entry.key);
    })
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Text('Chats')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Button('+ New chat')
          .fontSize(13)
          .height(36)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => {
            this.query = '';
            this.onNewChat();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 8 })
      TextInput({ placeholder: 'Search chats and tools', text: this.query })
        .height(38)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(10)
        .placeholderColor($r('app.color.text_hint'))
        .margin({ left: 16, right: 16, bottom: 6 })
        .onChange((value: string) => {
          this.query = value;
        })
      List({ space: 2 }) {
        if (this.searching()) {
          ForEach(toolGroups(this.query), (group: ToolGroup) => {
            ListItem() {
              Text(`TOOLS · ${group.title}`)
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .letterSpacing(0.6)
                .padding({ left: 16, top: 10, bottom: 2 })
            }
            ForEach(group.entries, (entry: ToolEntry) => {
              ListItem() {
                this.ToolRow(entry)
              }
            }, (entry: ToolEntry) => `tool-${entry.key}`)
          }, (group: ToolGroup) => `tg-${group.title}-${group.entries.length}-${this.query}`)
        }
        if (!this.hasChatMatch() && !this.searching()) {
          ListItem() {
            Text(this.sessions.length === 0
              ? 'No chats yet. Start one above.'
              : 'No chats match your search.')
              .fontSize(12)
              .fontColor($r('app.color.text_hint'))
              .padding({ left: 16, top: 12 })
          }
        } else if (this.searching() && !this.hasChatMatch() &&
          toolGroups(this.query).length === 0) {
          ListItem() {
            Text('Nothing matches your search.')
              .fontSize(12)
              .fontColor($r('app.color.text_hint'))
              .padding({ left: 16, top: 12 })
          }
        } else {
          ForEach(this.visibleSections(), (section: ChatSection) => {
            ListItem() {
              Text(section.label)
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .letterSpacing(0.6)
                .padding({ left: 16, top: 12, bottom: 4 })
            }
            ForEach(section.sessions, (session: ChatSession) => {
              ListItem() {
                this.ChatRow(session)
              }
              .swipeAction({ end: () => { this.DeleteAction(session) } })
            }, (session: ChatSession) => `${session.id}-${session.updatedAt}`)
          }, (section: ChatSection) => `cs-${section.label}-${section.sessions.length}-${this.query}`)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 20 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
