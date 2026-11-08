import { webview } from '@kit.ArkWeb';
import { AgentService } from '../../services/AgentService';
import { JsSandboxBridge } from '../../services/JsSandboxBridge';

/** The ArkWeb browser, its hidden sandbox and the URL intent from the catalogue. */
@Component
export struct BrowserPage {
  @State address: string = 'https://example.com';
  @State webSrc: string = 'https://example.com';
  @State pageUrl: string = '';
  @State message: string = '';
  @State agentWorking: boolean = false;
  @State canGoBack: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private sandboxController: webview.WebviewController = new webview.WebviewController();
  private timer: number = -1;

  aboutToAppear(): void {
    const requested: string = AgentService.get().browser.takeRequestedUrl();
    if (requested.length > 0) {
      this.address = requested;
      this.webSrc = requested;
      this.pageUrl = requested;
    }
    this.timer = setInterval(() => {
      this.agentWorking = AgentService.get().isBusy();
    }, 500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    AgentService.get().browser.detach();
  }

  private openAddress(): void {
    const url: string = this.address.trim();
    if (!url.startsWith('https://')) {
      this.message = 'Only https pages are allowed.';
      return;
    }
    try {
      this.controller.loadUrl(url);
      this.pageUrl = url;
      this.message = '';
    } catch (error) {
      this.message = `browser error: ${error}`;
    }
  }

  private goBack(): void {
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward();
      }
    } catch (error) {
      // The controller may not be attached yet.
    }
  }

  private reload(): void {
    try {
      this.controller.refresh();
    } catch (error) {
      // The controller may not be attached yet.
    }
  }

  build() {
    Column() {
      Web({ src: this.webSrc, controller: this.controller })
        .layoutWeight(1)
        .width('100%')
        .onPageEnd(() => {
          try {
            this.pageUrl = this.controller.getUrl();
            this.canGoBack = this.controller.accessBackward();
            if (this.pageUrl.startsWith('https://')) {
              this.address = this.pageUrl;
            }
          } catch (error) {
            this.pageUrl = this.address;
          }
          AgentService.get().browser.attach(this.controller);
        })
      if (this.agentWorking) {
        Text('HOPA is working on this page. It returns to Chat when the answer is ready.')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .padding({ left: 14, right: 14, top: 4, bottom: 2 })
          .maxLines(2)
      }
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(11)
          .fontColor($r('app.color.danger'))
          .width('100%')
          .padding({ left: 14, right: 14, top: 2, bottom: 2 })
          .maxLines(2)
      }
      Row({ space: 4 }) {
        Text('‹')
          .fontSize(24)
          .fontColor($r('app.color.text_primary'))
          .width(36)
          .height(38)
          .textAlign(TextAlign.Center)
          .opacity(this.canGoBack ? 1 : 0.3)
          .accessibilityText('Back')
          .onClick(() => {
            this.goBack();
          })
        TextInput({ text: this.address, placeholder: 'https://...' })
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(19)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.address = value;
          })
          .onSubmit(() => {
            this.openAddress();
          })
        Text('↻')
          .fontSize(19)
          .fontColor($r('app.color.text_primary'))
          .width(36)
          .height(38)
          .textAlign(TextAlign.Center)
          .accessibilityText('Reload')
          .onClick(() => {
            this.reload();
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 8 })
      .backgroundColor($r('app.color.surface'))
      .border({ width: { top: 1 }, color: $r('app.color.divider') })
      Web({ src: 'about:blank', controller: this.sandboxController })
        .width(1)
        .height(1)
        .opacity(0)
        .onPageEnd(() => {
          AgentService.get().sandbox.setBridge(new JsSandboxBridge(this.sandboxController));
        })
    }
    .width('100%')
    .height('100%')
  }
}
