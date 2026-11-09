/**
 * Placeholder for the HOPA laptop workbench.
 *
 * This module exists so the platform split is real and builds; the shell,
 * transport and pages arrive in the laptop milestone.
 */
@Entry
@Component
struct LaptopIndex {
  build() {
    Column({ space: 14 }) {
      Text('HOPA')
        .fontSize(44)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1B18')
      Text('HarmonyOS On-device Phone Agent — laptop shell')
        .fontSize(16)
        .fontColor('#6B665C')
        .textAlign(TextAlign.Center)
      Text('The shared core and transport are wired; the workbench lands here next.')
        .fontSize(13)
        .fontColor('#9A9488')
        .textAlign(TextAlign.Center)
        .constraintSize({ maxWidth: 520 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F7F4EE')
  }
}
