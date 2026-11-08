import { ToolEntry, ToolGroup, toolGroups } from '../../navigation/ToolCatalog';

/**
 * The Tools hub: every destination that does not need a bottom-bar slot.
 *
 * The hub has its own search and groups, so adding screens never makes the
 * shell longer or harder to scan.
 */
@Component
export struct MoreToolsPage {
  onNavigate: (key: string) => void = () => {};
  @State query: string = '';

  @Builder
  ToolRow(entry: ToolEntry) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(entry.title)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
        Text(entry.subtitle)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(17)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor($r('app.color.surface'))
    .borderRadius(10)
    .onClick(() => {
      this.query = '';
      this.onNavigate(entry.key);
    })
  }

  build() {
    Column({ space: 10 }) {
      Text('Apps, runs, models and phone setup.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
      TextInput({ placeholder: 'Search tools', text: this.query })
        .height(36)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(9)
        .placeholderColor($r('app.color.text_hint'))
        .onChange((value: string) => {
          this.query = value;
        })
      if (toolGroups(this.query).length === 0) {
        Text('Nothing matches your search.')
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
          .padding({ top: 12 })
      } else {
        List({ space: 4 }) {
          ForEach(toolGroups(this.query), (group: ToolGroup) => {
            ListItem() {
              Text(group.title)
                .fontSize(10)
                .fontColor($r('app.color.text_hint'))
                .letterSpacing(0.6)
                .padding({ left: 4, top: 10, bottom: 2 })
            }
            ForEach(group.entries, (entry: ToolEntry) => {
              ListItem() {
                this.ToolRow(entry)
              }
            }, (entry: ToolEntry) => entry.key)
          }, (group: ToolGroup) => `${group.title}-${group.entries.length}-${this.query}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 4 })
    .alignItems(HorizontalAlign.Start)
  }
}
