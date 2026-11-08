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

  @Builder
  Icon(label: string, action: string) {
    Text(label)
      .fontSize(24)
      .fontColor($r('app.color.text_primary'))
      .width(40)
      .height(40)
      .textAlign(TextAlign.Center)
      .backgroundColor($r('app.color.surface_muted'))
      .borderRadius(20)
      .onClick(() => {
        if (action === 'back') {
          if (this.controller.accessBackward()) {
            this.controller.backward();
          }
        } else if (action === 'forward') {
          if (this.controller.accessForward()) {
            this.controller.forward();
          }
        } else {
          this.controller.refresh();
        }
      })
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        this.Icon('‹', 'back')
        this.Icon('›', 'forward')
        this.Icon('↻', 'reload')
        TextInput({ text: this.address, placeholder: 'https://...' })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .onChange((value: string) => {
            this.address = value;
          })
          .onSubmit(() => {
            this.openAddress();
          })
        Button('Go')
          .fontSize(13)
          .width(52)
          .height(40)
          .onClick(() => {
            this.openAddress();
          })
      }
      .width('100%')
      Text(this.agentWorking
        ? 'HOPA is working on this page. It returns to Chat when the answer is ready.'
        : (this.pageUrl.length > 0
          ? `Ask HOPA in Chat to use this page. ${this.pageUrl}`
          : 'Open an https page, or ask HOPA in Chat.'))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(2)
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(11)
          .fontColor($r('app.color.danger'))
          .width('100%')
          .maxLines(2)
      }
      Web({ src: this.webSrc, controller: this.controller })
        .layoutWeight(1)
        .width('100%')
        .onPageEnd(() => {
          try {
            this.pageUrl = this.controller.getUrl();
          } catch (error) {
            this.pageUrl = this.address;
          }
          AgentService.get().browser.attach(this.controller);
        })
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
    .padding(8)
  }
}
