/** The page card after a web task: title, URL and Open. */
@Component
export struct ChatPageCard {
  @Prop title: string = '';
  @Prop url: string = '';
  onOpen: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.title.length > 0 ? this.title : 'Page HOPA read')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.url)
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
          this.onOpen();
        })
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.primary_soft'))
    .borderRadius(8)
  }
}
