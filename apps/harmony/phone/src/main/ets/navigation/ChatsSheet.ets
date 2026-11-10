import { ChatSession } from '@hopa/core';
import { ChatSection, searchSessions, sectionsOf } from './ChatSections';
import { LaptopSessionView, LaptopTurnView } from '../services/LaptopLink';

/**
 * The History sheet: searchable conversations, nothing else.
 *
 * The active chat is pinned above the date groups so it is always visible.
 * Empty sessions are not listed; a conversation appears after its first
 * message. Settings and Tools stay in the bottom bar.
 */
@Component
export struct ChatsSheet {
  @Prop sessions: ChatSession[] = [];
  @Prop currentId: string = '';
  @StorageLink('hopa.profile') profileName: string = 'everyday';
  /** The laptop's threads, read-only: they belong to the other machine. */
  @Prop laptopSessions: LaptopSessionView[] = [];
  @State query: string = '';
  @State searchOpen: boolean = false;
  @State viewingId: string = '';

  onNewChat: () => void = () => {};
  onSelect: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  onClose: () => void = () => {};
  /** Fork a laptop thread into a chat on this phone. */
  onContinueLaptop: (session: LaptopSessionView) => void = () => {};

  private real(): ChatSession[] {
    const result: ChatSession[] = [];
    for (const session of this.sessions) {
      if (session.entries.length > 0) {
        result.push(session);
      }
    }
    return result;
  }

  private currentSession(): ChatSession | undefined {
    for (const session of this.real()) {
      if (session.id === this.currentId) {
        return session;
      }
    }
    return undefined;
  }

  private others(): ChatSession[] {
    const current: ChatSession | undefined = this.currentSession();
    const result: ChatSession[] = [];
    for (const session of this.real()) {
      if (current === undefined || session.id !== current.id) {
        result.push(session);
      }
    }
    return result;
  }

  private searching(): boolean {
    return this.query.trim().length > 0;
  }

  private visibleSections(): ChatSection[] {
    const base: ChatSession[] = this.searching() ? this.real() : this.others();
    return sectionsOf(searchSessions(base, this.query), Date.now());
  }

  private showCurrent(): boolean {
    return !this.searching() && this.currentSession() !== undefined;
  }

  private hasResults(): boolean {
    const base: ChatSession[] = this.searching() ? this.real() : this.others();
    return searchSessions(base, this.query).length > 0;
  }

  private viewing(): LaptopSessionView | undefined {
    for (const session of this.laptopSessions) {
      if (session.id === this.viewingId) {
        return session;
      }
    }
    return undefined;
  }

  @Builder
  LaptopThread(session: LaptopSessionView) {
    Column() {
      Row({ space: 8 }) {
        Text('\u2190')
          .fontSize(20)
          .fontColor($r('app.color.text_primary'))
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.viewingId = '';
          })
        Column({ space: 1 }) {
          Text(session.title.length > 0 ? session.title : 'From your laptop')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('On your laptop \u00b7 read-only here')
            .fontSize(11)
            .fontColor($r('app.color.text_hint'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('Continue')
          .fontSize(12.5)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .onClick(() => {
            this.onContinueLaptop(session);
          })
      }
      .width('100%')
      .padding({ left: 6, right: 12, top: 4, bottom: 8 })

      List({ space: 10 }) {
        ForEach(session.turns, (turn: LaptopTurnView) => {
          ListItem() {
            Column({ space: 3 }) {
              Text(turn.role === 'user' ? 'You' : 'HOPA')
                .fontSize(9.5)
                .fontColor($r('app.color.text_hint'))
              Text(turn.text)
                .fontSize(13.5)
                .lineHeight(21)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(turn.role === 'user'
              ? $r('app.color.surface_muted')
              : $r('app.color.surface'))
            .borderRadius(12)
          }
        }, (turn: LaptopTurnView, index: number) => `${index}-${turn.role}`)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: 10, bottom: 16 })
  }

  private async confirmDelete(session: ChatSession): Promise<void> {
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: 'Delete this chat?',
        message: session.title.length > 0 ? session.title : 'Untitled chat',
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
  IconButton(kind: string) {
    Stack({ alignContent: Alignment.Center }) {
      if (kind === 'search') {
        Column()
          .width(13)
          .height(13)
          .borderRadius(6.5)
          .border({ width: 1.8, color: this.searchOpen
            ? $r('app.color.primary')
            : $r('app.color.text_secondary') })
          .offset({ x: -2, y: -2 })
        Row()
          .width(1.8)
          .height(7)
          .borderRadius(0.9)
          .backgroundColor(this.searchOpen
            ? $r('app.color.primary')
            : $r('app.color.text_secondary'))
          .rotate({ angle: -45 })
          .offset({ x: 5, y: 5 })
      } else {
        Text('✕')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width(40)
    .height(40)
    .accessibilityText(kind === 'search' ? 'Search chats' : 'Close history')
    .onClick(() => {
      if (kind === 'search') {
        this.searchOpen = !this.searchOpen;
        if (!this.searchOpen) {
          this.query = '';
        }
      } else {
        this.onClose();
      }
    })
  }

  @Builder
  NewChatRow() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(26)
          .height(26)
          .borderRadius(13)
          .backgroundColor($r('app.color.primary_soft'))
        Row().width(11).height(2).borderRadius(1).backgroundColor($r('app.color.primary'))
        Row().width(2).height(11).borderRadius(1).backgroundColor($r('app.color.primary'))
      }
      .width(30)
      .height(30)
      Text('New chat')
        .fontSize(14)
        .fontColor($r('app.color.primary'))
    }
    .width('100%')
    .height(46)
    .padding({ left: 10, right: 10 })
    .borderRadius(10)
    .onClick(() => {
      this.query = '';
      this.searchOpen = false;
      this.onNewChat();
    })
  }

  @Builder
  ChatRow(session: ChatSession) {
    Row({ space: 6 }) {
      Text(session.title.length > 0 ? session.title : 'Untitled chat')
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      if (session.id === this.currentId) {
        Text('✓')
          .fontSize(13)
          .fontColor($r('app.color.primary'))
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor(session.id === this.currentId
      ? $r('app.color.primary_soft')
      : $r('app.color.surface'))
    .onClick(() => {
      this.query = '';
      this.searchOpen = false;
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

  build() {
    Column() {
      if (this.viewing() !== undefined) {
        this.LaptopThread(this.viewing() as LaptopSessionView)
      } else {
      Row({ space: 2 }) {
        Text('Chats')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        this.IconButton('search')
        this.IconButton('close')
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 2, bottom: 4 })
      if (this.searchOpen) {
        TextInput({ placeholder: 'Search chats', text: this.query })
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(10)
          .placeholderColor($r('app.color.text_hint'))
          .margin({ left: 16, right: 16, bottom: 6 })
          .onChange((value: string) => {
            this.query = value;
          })
      }
      // Easy and Kid never open a chat session, so "New chat" is noise there.
      if (this.profileName !== 'easy' && this.profileName !== 'kid') {
        this.NewChatRow()
      }
      List({ space: 2 }) {
        if (this.showCurrent()) {
          ListItem() {
            Text('Current')
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.6)
              .padding({ left: 12, top: 10, bottom: 2 })
          }
          ListItem() {
            this.ChatRow(this.currentSession() as ChatSession)
          }
        }
        if (this.hasResults()) {
          ForEach(this.visibleSections(), (section: ChatSection) => {
            ListItem() {
              Text(section.label)
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .letterSpacing(0.6)
                .padding({ left: 12, top: 10, bottom: 2 })
            }
            ForEach(section.sessions, (session: ChatSession) => {
              ListItem() {
                this.ChatRow(session)
              }
              .swipeAction({ end: () => { this.DeleteAction(session) } })
            }, (session: ChatSession) => `${session.id}-${session.updatedAt}`)
          }, (section: ChatSection) => `cs-${section.label}-${section.sessions.length}-${this.query}`)
        } else if (!this.showCurrent()) {
          ListItem() {
            Text(this.searching() ? 'No chats match your search.' : 'No chats yet.')
              .fontSize(12)
              .fontColor($r('app.color.text_hint'))
              .padding({ left: 12, top: 12 })
          }
        }
        if (this.laptopSessions.length > 0 && !this.searching()) {
          ListItem() {
            Text(`FROM YOUR LAPTOP \u00b7 ${this.laptopSessions.length}`)
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.6)
              .padding({ left: 12, top: 14, bottom: 2 })
          }
          ForEach(this.laptopSessions.slice(0, 20), (session: LaptopSessionView) => {
            ListItem() {
              Row({ space: 8 }) {
                Image($r('app.media.hopa_body_laptop'))
                  .width(14)
                  .height(14)
                  .objectFit(ImageFit.Contain)
                  .opacity(0.6)
                Text(session.title.length > 0 ? session.title : 'Untitled chat')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                Text('\u2192')
                  .fontSize(11)
                  .fontColor($r('app.color.text_hint'))
              }
              .width('100%')
              .height(46)
              .padding({ left: 12, right: 12 })
              .borderRadius(10)
              .backgroundColor($r('app.color.surface'))
              .onClick(() => {
                this.viewingId = session.id;
              })
            }
          }, (session: LaptopSessionView) => 'lap-' + session.id + session.title)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 8, right: 8, bottom: 20 })
      .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
