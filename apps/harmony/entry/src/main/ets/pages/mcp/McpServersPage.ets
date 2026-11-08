/** What runs on the phone and what runs on the PC. */
@Component
export struct McpServersPage {
  build() {
    Column({ space: 12 }) {
      Text('On this phone')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('This build does not run an MCP server on the device. The app is a client of the PC agent, not a server.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Text('On the computer')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('pc-agent mcp    # stdio MCP server for Claude/other clients')
        .fontSize(11)
        .backgroundColor($r('app.color.surface_muted'))
        .padding(8)
        .borderRadius(6)
        .width('100%')
      Text('pc-agent bridge --host 0.0.0.0 --port 8765 --token <token>')
        .fontSize(11)
        .backgroundColor($r('app.color.surface_muted'))
        .padding(8)
        .borderRadius(6)
        .width('100%')
      Text('Some assistants expose MCP servers in Settings. HOPA keeps MCP on the PC side; the phone talks to the bridge over HTTP with a token.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
