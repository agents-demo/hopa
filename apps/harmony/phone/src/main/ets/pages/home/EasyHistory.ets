import { Context } from '@kit.AbilityKit';
import { EasyEntry, EasyLog } from '../../services/EasyLog';
import { StyleProfile } from '../../services/StyleProfile';
import { HopaMark } from '../chat/HopaMark';

/** Easy history: what was asked, what HOPA answered, when. Tap for detail. */
@Component
export struct EasyHistory {
  onOpenHome: () => void = () => {};
  @State entries: EasyEntry[] = [];
  @State selected: number = -1;
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

  private askAgain(entry: EasyEntry): void {
    AppStorage.setOrCreate<string>('hopa.easyDraft', entry.goal);
    AppStorage.setOrCreate<boolean>('hopa.easyOpenTask', true);
    this.onOpenHome();
  }

  @Builder
  Card(entry: EasyEntry, index: number) {
    Column({ space: 6 }) {
      Text(new Date(entry.at).toLocaleString())
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
      Text(entry.goal)
        .fontSize(this.style().body + 1)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(entry.answer)
        .fontSize(this.style().body - 1)
        .lineHeight(this.style().body + 5)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.divider') })
    .borderRadius(this.style().cardRadius)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.selected = index;
    })
  }

  @Builder
  Detail(entry: EasyEntry) {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('←')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.selected = -1;
          })
        Text('What you asked')
          .fontSize(this.style().body + 2)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      Text(new Date(entry.at).toLocaleString())
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
      Text(entry.goal)
        .fontSize(this.style().body + 3)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Scroll() {
        Text(entry.answer)
          .fontSize(this.style().body + 2)
          .lineHeight(this.style().body + 11)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      Text('Edit this request')
        .fontSize(this.style().body + 1)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.on_primary'))
        .width('100%')
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(this.style().cardRadius)
        .onClick(() => {
          this.askAgain(entry);
        })

    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 10, bottom: 48 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.selected >= 0 && this.selected < this.entries.length) {
      this.Detail(this.entries[this.selected])
    } else {
      Scroll() {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text('←')
              .fontSize(24)
              .fontColor($r('app.color.text_primary'))
              .width(44)
              .height(44)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.onOpenHome();
              })
            Text('History')
              .fontSize(this.style().body + 2)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          if (this.entries.length > 0) {
            Text(`${this.entries.length} things you asked`)
              .fontSize(this.style().body - 2)
              .fontColor($r('app.color.text_hint'))
              .width('100%')
          }
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
}
