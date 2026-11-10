import { common, Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

interface ShareWant {
  uri?: string;
  parameters?: Record<string, Object>;
}

interface ShareRecord {
  text?: string;
  uri?: string;
  title?: string;
  debug?: string;
  raw?: string;
}

const RECORD_FILE: string = 'share_record.json';

/**
 * The share sheet another app shows when the user picks HOPA.
 *
 * It does one thing: take whatever was shared, show it, and hand it to the
 * conversation. Nothing is acted on here; approvals still happen in HOPA.
 */
@Entry
@Component
struct ShareSheet {
  @State sharedText: string = '';
  @State sharedUri: string = '';
  @State sharedTitle: string = '';
  @State debug: string = '';
  @State rawWant: string = '';
  @State status: string = '';

  aboutToAppear(): void {
    this.sharedText = AppStorage.get<string>('hopa.share.text') ?? '';
    this.sharedUri = AppStorage.get<string>('hopa.share.uri') ?? '';
    this.sharedTitle = AppStorage.get<string>('hopa.share.title') ?? '';
    this.debug = AppStorage.get<string>('hopa.share.debug') ?? '';
    this.rawWant = AppStorage.get<string>('hopa.share.raw') ?? '';
    if (this.sharedText.length === 0 && this.sharedUri.length === 0 && this.sharedTitle.length === 0) {
      this.loadFromFile();
    }
  }

  /** The state handoff is not guaranteed; the sandbox record is. */
  private loadFromFile(): void {
    try {
      const context = getContext(this) as common.UIExtensionContext;
      const path: string = `${context.filesDir}/${RECORD_FILE}`;
      if (!fileIo.accessSync(path)) {
        return;
      }
      const raw: string = fileIo.readTextSync(path);
      const record = JSON.parse(raw) as ShareRecord;
      this.sharedText = record.text ?? '';
      this.sharedUri = record.uri ?? '';
      this.sharedTitle = record.title ?? '';
      this.debug = record.debug ?? '';
      this.rawWant = record.raw ?? '';
    } catch (error) {
      this.debug = 'record unreadable';
    }
  }

  /** Systems that do not answer ShareKit still pass a URI in the want. */
  private uriFromWant(): string {
    if (this.rawWant.length === 0) {
      return '';
    }
    try {
      const parsed = JSON.parse(this.rawWant) as ShareWant;
      const params: Record<string, Object> | undefined = parsed.parameters;
      if (params === undefined) {
        return '';
      }
      const keys: string[] = Object.keys(params);
      for (const key of keys) {
        const value: Object = params[key];
        if (typeof value === 'string' && this.isUri(value as string)) {
          return value as string;
        }
        if (Array.isArray(value)) {
          const list: Object[] = value as Object[];
          for (const item of list) {
            if (typeof item === 'string' && this.isUri(item as string)) {
              return item as string;
            }
          }
        }
      }
    } catch (error) {
      return '';
    }
    return '';
  }

  private isUri(value: string): boolean {
    return value.startsWith('file://') || value.startsWith('datashare://') ||
      value.startsWith('content://') || value.startsWith('http');
  }

  private resolvedUri(): string {
    return this.sharedUri.length > 0 ? this.sharedUri : this.uriFromWant();
  }

  private preview(): string {
    if (this.sharedText.length > 0) {
      return this.sharedText;
    }
    if (this.sharedTitle.length > 0) {
      return this.sharedTitle;
    }
    const uri: string = this.resolvedUri();
    if (uri.length > 0) {
      const name: string = uri.substring(uri.lastIndexOf('/') + 1);
      return name.length > 0 ? name : uri;
    }
    return '';
  }

  private payload(): string {
    if (this.sharedText.length > 0) {
      return this.sharedText;
    }
    if (this.resolvedUri().length > 0) {
      return this.resolvedUri();
    }
    return this.sharedTitle;
  }

  private ask(): void {
    const text: string = this.payload();
    if (text.length === 0) {
      this.status = 'Nothing readable to send.';
      return;
    }
    const context = getContext(this) as common.UIExtensionContext;
    const params: Record<string, Object> = { 'hopa.sharedText': text };
    const want: Want = {
      bundleName: 'com.hopa.agent',
      abilityName: 'EntryAbility',
      parameters: params
    };
    context.startAbility(want).then(() => {
      context.terminateSelf();
    }).catch(() => {
      this.status = 'HOPA could not open.';
    });
  }

  private cancel(): void {
    const context = getContext(this) as common.UIExtensionContext;
    context.terminateSelf();
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.primary'))
        Text('Share with HOPA')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')

      if (this.preview().length > 0) {
        Text(this.preview())
          .fontSize(13)
          .lineHeight(19)
          .fontColor($r('app.color.text_primary'))
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding(12)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(10)
        Text(this.sharedUri.length > 0 && this.sharedText.length === 0
          ? 'HOPA gets this file. Nothing is read from it until you ask.'
          : 'It goes into the message box. Nothing runs until you send it.')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      } else {
        Text('This share has no readable text yet.')
          .fontSize(13)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text('Pictures and files arrive as a path; text is previewed here.')
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
        Text(`records: ${this.debug}`)
          .fontSize(9)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      Row({ space: 8 }) {
        Button('Open in HOPA')
          .height(40)
          .layoutWeight(1)
          .fontSize(13)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.on_primary'))
          .enabled(this.payload().length > 0)
          .onClick(() => {
            this.ask();
          })
        Button('Cancel')
          .height(40)
          .fontSize(13)
          .backgroundColor($r('app.color.surface_muted'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.cancel();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
  }
}
