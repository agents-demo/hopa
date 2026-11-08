import { Context } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { AgentService } from '../../services/AgentService';

/** Exports memory, skills and runs, then shows the JSON in place. */
@Component
export struct FilesPage {
  @State fileText: string = '';
  @State filePath: string = 'not exported';

  private async load(): Promise<void> {
    try {
      const path: string = await AgentService.get().exportData(getContext(this) as Context);
      this.filePath = path;
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const data = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, data);
      fileIo.closeSync(file);
      this.fileText = buffer.from(data).toString('utf8');
    } catch (error) {
      this.filePath = `export failed: ${error}`;
    }
  }

  build() {
    Column({ space: 10 }) {
      Text('Exports')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      Text('Memory, skills and runs are written as one JSON file in the app sandbox.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      Button('Export and load')
        .fontSize(12)
        .onClick(() => {
          this.load();
        })
      Text(this.filePath)
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
        .maxLines(2)
      if (this.fileText.length > 0) {
        Scroll() {
          Text(this.fileText)
            .fontSize(9)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor($r('app.color.surface_alt'))
        .padding(8)
        .borderRadius(8)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
