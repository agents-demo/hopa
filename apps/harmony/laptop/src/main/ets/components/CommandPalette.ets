/**
 * The command palette: a scrim, a search field, and grouped destinations.
 *
 * A flat list of ten rows is not a palette — it is a menu. Modern palettes are
 * searchable and grouped, and the keyboard is already in the field, so this
 * opens focused with the caret ready.
 */
class PaletteItem {
  label: string = '';
  run: () => void = () => {};

  constructor(label: string, run: () => void) {
    this.label = label;
    this.run = run;
  }
}

class PaletteGroup {
  title: string = '';
  items: PaletteItem[] = [];

  constructor(title: string) {
    this.title = title;
  }
}

@Component
export struct CommandPalette {
  onNewChat: () => void = () => {};
  onSettings: () => void = () => {};
  onGo: (target: string) => void = () => {};
  onClose: () => void = () => {};

  @State query: string = '';

  private groups(): PaletteGroup[] {
    const go = new PaletteGroup('Go to');
    go.items.push(new PaletteItem('Activity', () => this.onGo('activity')));
    go.items.push(new PaletteItem('Plans', () => this.onGo('plans')));
    go.items.push(new PaletteItem('Capabilities', () => this.onGo('abilities')));
    go.items.push(new PaletteItem('Memory', () => this.onGo('memory')));
    go.items.push(new PaletteItem('Skills', () => this.onGo('skills')));
    go.items.push(new PaletteItem('Usage', () => this.onGo('usage')));
    go.items.push(new PaletteItem('Launchpad', () => this.onGo('launchpad')));
    go.items.push(new PaletteItem('Browser', () => this.onGo('browser')));

    const session = new PaletteGroup('Conversation');
    session.items.push(new PaletteItem('New chat', () => this.onNewChat()));

    const app = new PaletteGroup('App');
    app.items.push(new PaletteItem('Settings', () => this.onSettings()));

    const all: PaletteGroup[] = [session, go, app];
    const needle: string = this.query.trim().toLowerCase();
    if (needle.length === 0) {
      return all;
    }
    const filtered: PaletteGroup[] = [];
    for (const group of all) {
      const kept: PaletteItem[] = [];
      for (const item of group.items) {
        if (item.label.toLowerCase().includes(needle)) {
          kept.push(item);
        }
      }
      if (kept.length > 0) {
        const copy = new PaletteGroup(group.title);
        copy.items = kept;
        filtered.push(copy);
      }
    }
    return filtered;
  }

  @Builder
  Heading(text: string) {
    Text(text.toUpperCase())
      .fontSize(9)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.text_hint'))
      .letterSpacing(0.7)
      .width('100%')
      .padding({ left: 10, top: 10, bottom: 3 })
  }

  @Builder
  Row(item: PaletteItem) {
    Row() {
      Text(item.label)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
      Blank()
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .borderRadius(8)
    .onClick(() => {
      item.run();
      this.onClose();
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#33000000')
        .onClick(() => {
          this.onClose();
        })
      Column({ space: 2 }) {
        TextInput({ text: this.query, placeholder: 'Go to, or type a command' })
          .width('100%')
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(9)
          .margin({ bottom: 6 })
          .onChange((value: string) => {
            this.query = value;
          })

        if (this.groups().length === 0) {
          Text('Nothing matches that.')
            .fontSize(12)
            .fontColor($r('app.color.text_hint'))
            .padding({ left: 10, top: 8, bottom: 8 })
        } else {
          ForEach(this.groups(), (group: PaletteGroup) => {
            this.Heading(group.title)
            ForEach(group.items, (item: PaletteItem) => {
              this.Row(item)
            }, (item: PaletteItem) => group.title + item.label)
          }, (group: PaletteGroup) => 'g-' + group.title + group.items.length)
        }
      }
      .width(460)
      .padding(10)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .shadow({ radius: 24, color: '#33000000', offsetY: 8 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}
