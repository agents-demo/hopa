import { common, Want } from '@kit.AbilityKit';

interface ShareWant {
  uri?: string;
  parameters?: Record<string, Object>;
}

/**
 * The share sheet another app shows when the user picks HOPA.
 *
 * It does one thing: take whatever was shared, show it, and hand it to the
 * conversation. Nothing is acted on here; approvals still happen in HOPA.
 */
@Entry
@Component
struct ShareSheet {
  @StorageProp('hopa.share.text') sharedText: string = '';
  @StorageProp('hopa.share.uri') sharedUri: string = '';
  @StorageProp('hopa.share.title') sharedTitle: string = '';
  @StorageProp('hopa.share.debug') debug: string = '';
  @StorageProp('hopa.share.raw') rawWant: string = '';
  @State status: string = '';

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
        if (typeof value === 'string' && (value as string).startsWith('file://')) {
          return value as string;
        }
        if (Array.isArray(value)) {
          const list: Object[] = value as Object[];
          for (const item of list) {
            if (typeof item === 'string' && (item as string).startsWith('file://')) {
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
