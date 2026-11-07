/** The four pages that do not fit above the Tools group. */
@Component
export struct MoreToolsPage {
  onNavigate: (key: string) => void = () => {};

  @Builder
  Row(title: string, subtitle: string, key: string) {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
        Text(subtitle)
          .fontSize(11)
          .fontColor('#999999')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('>')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#F7F8FA')
    .borderRadius(10)
    .onClick(() => {
      this.onNavigate(key);
    })
  }

  build() {
    Column({ space: 10 }) {
      Text('More')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('The screens Mika keeps in its drawer that do not fit above.')
        .fontSize(12)
        .fontColor('#666666')
      this.Row('Source', 'Model, backend and observation source', 'source')
      this.Row('MCP servers', 'What runs on the phone and what runs on the PC', 'mcpservers')
      this.Row('Files', 'Exported data on this device', 'files')
      this.Row('License', 'Apache-2.0 and third-party notices', 'license')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
