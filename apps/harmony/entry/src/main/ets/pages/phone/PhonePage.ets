import { AgentService } from '../../services/AgentService';

/** What the phone can do today and how to attach the PC. */
@Component
export struct PhonePage {
  onOpenSettings: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text('Accessibility')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text(AgentService.get().isAccessibilityAvailable()
        ? 'The service is available. The loop can read and tap other apps on the phone.'
        : 'The service cannot be enabled on this emulator. Use the PC bridge below, or a device with an accessibility settings page.')
        .fontSize(12)
        .fontColor('#666666')
      Text('PC bridge')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text(AgentService.get().isBridgeConfigured()
        ? 'A bridge is configured. It is the active control backend.'
        : 'No bridge yet. Run pc-agent bridge on the PC, then enter the URL and token in Settings.')
        .fontSize(12)
        .fontColor('#666666')
      Text('1. pc-agent bridge --host 0.0.0.0 --port 8765 --token <token>')
        .fontSize(11)
        .fontColor('#999999')
      Text('2. Emulator: http://10.0.2.2:8765. Phone on Wi-Fi: the PC LAN address.')
        .fontSize(11)
        .fontColor('#999999')
      Text('3. Settings -> PC bridge -> Connect. The status must read connected.')
        .fontSize(11)
        .fontColor('#999999')
      Button('Open Settings')
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
