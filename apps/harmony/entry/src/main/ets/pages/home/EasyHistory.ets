import { Context } from '@kit.AbilityKit';
import { EasyEntry, EasyLog } from '../../services/EasyLog';
import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Easy history: what was asked, what HOPA answered, when. */
@Component
export struct EasyHistory {
  @State entries: EasyEntry[] = [];
  @State expanded: number = -1;
  @StorageLink('hopa.style') styleName: string = 'easy';

  aboutToAppear(): void {
    const context = getContext(this) as Context;
    EasyLog.load(context).then(() => {
      this.entries = EasyLog.all().slice();
    }).catch(() => {
      this.entries = [];
    });
  }

  private style(): StyleProfile {
    return StyleProfile.of(this.styleName);
  }

  @Builder
  Card(entry: EasyEntry, index: number) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(new Date(entry.at).toLocaleString())
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
        Blank()
        if (this.expanded === index) {
          Text('Less')
            .fontSize(10)
            .fontColor($r('app.color.primary'))
        } else {
          Text('More')
            .fontSize(10)
            .fontColor($r('app.color.primary'))
        }
      }
      .width('100%')
      Text(entry.goal)
        .fontSize(this.style().body + 1)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(entry.answer)
        .fontSize(this.style().body)
        .lineHeight(this.style().body + 8)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(this.expanded === index ? 60 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(this.style().cardRadius)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.expanded = this.expanded === index ? -1 : index;
    })
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Text('What you asked')
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        if (this.entries.length === 0) {
          Column({ space: 8 }) {
            HopaMark({ state: 'idle', markSize: 56, interactive: false })
            Text('Nothing here yet')
              .fontSize(this.style().body + 1)
              .fontWeight(FontWeight.Medium)
            Text('Tap Talk on the home screen and ask for something.')
              .fontSize(this.style().body - 1)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ top: 60 })
        } else {
          ForEach(this.entries, (entry: EasyEntry, index: number) => {
            this.Card(entry, index)
          }, (entry: EasyEntry, index: number) => `${entry.at}-${index}`)
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
