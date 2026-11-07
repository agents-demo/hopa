/** Apache-2.0 and third-party notices. */
@Component
export struct LicensePage {
  build() {
    Column({ space: 12 }) {
      Text('Apache License 2.0')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Text('HOPA is distributed under the Apache License, Version 2.0. You may use, modify and redistribute it under the terms of that license, including the patent grant and the notice requirements.')
        .fontSize(12)
        .fontColor('#666666')
      Text('Third-party components')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('HarmonyOS ArkUI, ArkWeb, ArkData and the DevEco SDK are used under the Huawei/OpenHarmony terms.')
        .fontSize(11)
        .fontColor('#999999')
      Text('No third-party agent code runs in this app. Device control is implemented with hdc, uitest and the HarmonyOS accessibility API.')
        .fontSize(11)
        .fontColor('#999999')
      Text('DeepSeek, OpenAI, Anthropic and Gemini are accessed through their public HTTP APIs with the user-provided key.')
        .fontSize(11)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
