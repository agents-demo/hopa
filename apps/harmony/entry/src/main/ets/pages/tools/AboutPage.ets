/** Version, credits and licenses. */
@Component
export struct AboutPage {
  build() {
    Column({ space: 12 }) {
      Text('HOPA')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
      Text('HarmonyOS phone agent.')
        .fontSize(13)
        .fontColor('#666666')
      Text('Version 0.1.0')
        .fontSize(12)
      Text('The agent loop, the payment gate and the PC bridge are original work. This app contains no Kotlin or Python at runtime.')
        .fontSize(11)
        .fontColor('#999999')
      Text('Licenses')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('HOPA is distributed under the Apache License 2.0. ArkWeb, ArkUI, hdc and the HarmonyOS SDK are used under their own terms.')
        .fontSize(11)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
