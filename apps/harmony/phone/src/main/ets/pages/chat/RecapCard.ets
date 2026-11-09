import { HopaMark } from './HopaMark';

/** The image content of a sharable recap. */
@Component
export struct RecapCard {
  @Prop goal: string = '';
  @Prop answer: string = '';
  @Prop steps: string[] = [];

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        HopaMark({ state: 'idle', markSize: 26 })
        Text('HOPA')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1B18')
        Blank()
        Text(new Date().toLocaleDateString())
          .fontSize(10)
          .fontColor('#6B6A63')
      }
      .width('100%')
      Text(this.goal.length > 0 ? this.goal : 'A HOPA session')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1B18')
        .width('100%')
        .maxLines(3)
      if (this.steps.length > 0) {
        Column({ space: 6 }) {
          ForEach(this.steps.slice(0, 5), (step: string, index: number) => {
            Row({ space: 8 }) {
              Text(`${index + 1}`)
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .fontColor('#E8703A')
                .width(16)
                .height(16)
                .textAlign(TextAlign.Center)
                .backgroundColor('#1AE8703A')
                .borderRadius(8)
              Text(step.substring(2))
                .fontSize(11.5)
                .fontColor('#3E3D38')
                .layoutWeight(1)
                .maxLines(2)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (step: string, index: number) => `recap-${index}-${step}`)
        }
        .width('100%')
      } else {
        Text(this.answer)
          .fontSize(12)
          .fontColor('#3E3D38')
          .width('100%')
          .maxLines(4)
      }
      Divider().color('#141C1B18')
      Text('HarmonyOS On-device Phone Agent')
        .fontSize(9)
        .fontColor('#6B6A63')
        .letterSpacing(0.4)
    }
    .width(300)
    .padding(18)
    .backgroundColor('#FFFDFBF7')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }
}
