import { Context } from '@kit.AbilityKit';
import { ErrorLog, LogEntry } from '../../services/ErrorLog';

/** The on-device list of recent failures (no telemetry). */
@Component
export struct LogsView {
  @State entries: LogEntry[] = [];

  aboutToAppear(): void {
    const context = getContext(this) as Context;
    ErrorLog.load(context).then(() => {
      this.entries = ErrorLog.all().slice();
    }).catch(() => {
      this.entries = [];
    });
  }

  private async clear(): Promise<void> {
    const context = getContext(this) as Context;
    await ErrorLog.clear(context);
    this.entries = [];
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(`${this.entries.length} recent problems`)
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
          .layoutWeight(1)
        if (this.entries.length > 0) {
          Text('Clear')
            .fontSize(11)
            .fontColor($r('app.color.danger'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.surface_alt'))
            .borderRadius(8)
            .onClick(() => {
              this.clear();
            })
        }
      }
      .width('100%')

      if (this.entries.length === 0) {
        Text('Nothing has failed recently.')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding(14)
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(10)
      } else {
        List({ space: 8 }) {
          ForEach(this.entries, (entry: LogEntry) => {
            ListItem() {
              Column({ space: 4 }) {
                Text(new Date(entry.at).toLocaleString())
                  .fontSize(10)
                  .fontColor($r('app.color.text_hint'))
                Text(entry.message)
                  .fontSize(11.5)
                  .fontColor($r('app.color.text_primary'))
                  .width('100%')
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface_alt'))
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)
            }
          }, (entry: LogEntry) => `${entry.at}-${entry.message}`)
        }
        .width('100%')
        .layoutWeight(1)
      }
      Text('Kept on this phone only. HOPA sends no logs anywhere.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
