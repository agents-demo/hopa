import { AgentService } from '../../services/AgentService';

/** How a computer can drive this phone. */
@Component
export struct ComputerAccessPage {
  onOpenSettings: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text(AgentService.get().isBridgeConfigured()
        ? 'The PC bridge is connected. The phone can be driven from the computer.'
        : 'The PC bridge is not connected. Start it on the computer, then connect in Settings.')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Text('Commands')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('pc-agent bridge --host 0.0.0.0 --port 8765 --token <token>')
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_muted'))
        .padding(8)
        .borderRadius(6)
        .width('100%')
      Text('pc-agent mcp    # drive the phone from an MCP client')
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_muted'))
        .padding(8)
        .borderRadius(6)
        .width('100%')
      Text('The app is the client; it does not run an MCP server on the phone.')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Text('Endpoints: /observe, /tap, /type, /launch, /key, /swipe, /screenshot')
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Button('Open bridge settings')
        .fontSize(12)
        .onClick(() => {
          this.onOpenSettings();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
