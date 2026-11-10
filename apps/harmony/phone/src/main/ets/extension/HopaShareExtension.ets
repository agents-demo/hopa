import ShareExtensionAbility from '@ohos.app.ability.ShareExtensionAbility';
import { Want, UIExtensionContentSession } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA.share';
const RECORD_FILE: string = 'share_record.json';

class ShareRecord {
  text: string = '';
  uri: string = '';
  title: string = '';
  debug: string = '';
  raw: string = '';
}

/**
 * Receives text, images and files from other apps.
 *
 * The sheet only previews what arrived and hands it to the main ability; the
 * conversation starts there, with the normal composer and approvals.
 *
 * The record is written to the extension sandbox as well as to AppStorage:
 * the sheet must still work if the UI-state handoff is not available.
 */
export default class HopaShareExtension extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    systemShare.getSharedData(want).then((data: systemShare.SharedData) => {
      const records: systemShare.SharedRecord[] = data.getRecords();
      const record = new ShareRecord();
      const parts: string[] = [];
      const debug: string[] = [];
      for (const item of records) {
        const content: string = item.content ?? '';
        if (content.length > 0) {
          parts.push(content);
        } else if (item.uri !== undefined && item.uri.length > 0) {
          record.uri = item.uri;
        }
        if (item.title !== undefined && item.title.length > 0 && record.title.length === 0) {
          record.title = item.title;
        }
        debug.push(`${item.utd}|${item.content !== undefined}|${item.uri ?? ''}|${item.title ?? ''}`);
      }
      record.text = parts.join('\n');
      record.debug = debug.join(' | ');
      record.raw = JSON.stringify(want);
      hilog.info(DOMAIN, TAG, 'shared records: %{public}d', records.length);
      this.finish(record, session);
    }).catch(() => {
      hilog.warn(DOMAIN, TAG, 'share data unavailable');
      const record = new ShareRecord();
      record.debug = 'no records';
      record.raw = JSON.stringify(want);
      this.finish(record, session);
    });
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    hilog.info(DOMAIN, TAG, 'share session closed');
  }

  private finish(record: ShareRecord, session: UIExtensionContentSession): void {
    const body: string = JSON.stringify(record);
    AppStorage.setOrCreate<string>('hopa.share.text', record.text);
    AppStorage.setOrCreate<string>('hopa.share.uri', record.uri);
    AppStorage.setOrCreate<string>('hopa.share.title', record.title);
    AppStorage.setOrCreate<string>('hopa.share.debug', record.debug);
    AppStorage.setOrCreate<string>('hopa.share.raw', record.raw);
    try {
      const path: string = `${this.context.filesDir}/${RECORD_FILE}`;
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, body);
      fileIo.closeSync(file);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, 'share record not written');
    }
    session.loadContent('pages/share/ShareSheet');
  }
}
