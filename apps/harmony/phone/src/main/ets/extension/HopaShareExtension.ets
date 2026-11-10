import ShareExtensionAbility from '@ohos.app.ability.ShareExtensionAbility';
import { Want, UIExtensionContentSession } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'HOPA.share';

/**
 * Receives text, images and files from other apps.
 *
 * The sheet only previews what arrived and hands it to the main ability; the
 * conversation starts there, with the normal composer and approvals.
 */
export default class HopaShareExtension extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    systemShare.getSharedData(want).then((data: systemShare.SharedData) => {
      const records: systemShare.SharedRecord[] = data.getRecords();
      const parts: string[] = [];
      let uri: string = '';
      let title: string = '';
      for (const record of records) {
        const content: string = record.content ?? '';
        if (content.length > 0) {
          parts.push(content);
          continue;
        }
        if (record.uri !== undefined && record.uri.length > 0) {
          uri = record.uri;
        }
        if (record.title !== undefined && record.title.length > 0 && title.length === 0) {
          title = record.title;
        }
      }
      hilog.info(DOMAIN, TAG, 'shared records: %{public}d', records.length);
      const debug: string[] = [];
      for (const record of records) {
        debug.push(`${record.utd}|${record.content !== undefined}|${record.uri ?? ''}|${record.title ?? ''}`);
      }
      AppStorage.setOrCreate<string>('hopa.share.text', parts.join('\n'));
      AppStorage.setOrCreate<string>('hopa.share.uri', uri);
      AppStorage.setOrCreate<string>('hopa.share.title', title);
      AppStorage.setOrCreate<string>('hopa.share.debug', debug.join(' | '));
      AppStorage.setOrCreate<string>('hopa.share.raw', JSON.stringify(want));
      session.loadContent('pages/share/ShareSheet');
    }).catch(() => {
      hilog.warn(DOMAIN, TAG, 'share data unavailable');
      AppStorage.setOrCreate<string>('hopa.share.text', '');
      AppStorage.setOrCreate<string>('hopa.share.uri', '');
      AppStorage.setOrCreate<string>('hopa.share.title', '');
      AppStorage.setOrCreate<string>('hopa.share.debug', 'no records');
      AppStorage.setOrCreate<string>('hopa.share.raw', JSON.stringify(want));
      session.loadContent('pages/share/ShareSheet');
    });
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    hilog.info(DOMAIN, TAG, 'share session closed');
  }
}
