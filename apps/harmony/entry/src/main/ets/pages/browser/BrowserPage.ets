import { webview } from '@kit.ArkWeb';
import { AgentService } from '../../services/AgentService';
import { JsSandboxBridge } from '../../services/JsSandboxBridge';

/** The ArkWeb browser, its sandbox and the URL intent from the catalogue. */
@Component
export struct BrowserPage {
  @State address: string = 'https://example.com';
  @State pageUrl: string = '';
  @State script: string = '';
  @State scriptOutput: string = '';
  private controller: webview.WebviewController = new webview.WebviewController();
  private sandboxController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const requested: string = AgentService.get().browser.takeRequestedUrl();
    if (requested.length > 0) {
      this.address = requested;
      try {
        this.controller.loadUrl(requested);
        this.pageUrl = requested;
      } catch (error) {
        this.scriptOutput = `browser error: ${error}`;
      }
    }
  }

  private openAddress(): void {
    const url: string = this.address.trim();
    if (!url.startsWith('https://')) {
      this.scriptOutput = 'Only https pages are allowed.';
      return;
    }
    try {
      this.controller.loadUrl(url);
      this.pageUrl = url;
    } catch (error) {
      this.scriptOutput = `browser error: ${error}`;
    }
  }

  private async runScript(): Promise<void> {
    const code: string = this.script.trim();
    if (code.length === 0) {
      return;
    }
    try {
      const bridge = new JsSandboxBridge(this.sandboxController);
      this.scriptOutput = await bridge.run(code, 'javascript');
    } catch (error) {
      this.scriptOutput = `error: ${error}`;
    }
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.address, placeholder: 'https://...' })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.address = value;
          })
          .onSubmit(() => {
            this.openAddress();
          })
        Button('Go')
          .onClick(() => {
            this.openAddress();
          })
      }
      .width('100%')
      Text(this.pageUrl.length > 0
        ? `${this.pageUrl} - ask in Chat, HOPA can read and click this page`
        : 'Load an https page, then ask HOPA in Chat.')
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
        .maxLines(2)
      Row({ space: 8 }) {
        Button('Back')
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            if (this.controller.accessBackward()) {
              this.controller.backward();
            }
          })
        Button('Forward')
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            if (this.controller.accessForward()) {
              this.controller.forward();
            }
          })
        Button('Reload')
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            this.controller.refresh();
          })
      }
      .width('100%')
      Text('JavaScript sandbox (isolated about:blank page, offline)')
        .fontSize(12)
        .fontColor('#666666')
      TextArea({ placeholder: '1 + 1', text: this.script })
        .height(70)
        .onChange((value: string) => {
          this.script = value;
        })
      Button('Run script')
        .fontSize(12)
        .onClick(() => {
          this.runScript();
        })
      Text(this.scriptOutput)
        .fontSize(11)
        .fontColor('#0A7F3F')
        .maxLines(4)
      Web({ src: 'https://example.com', controller: this.controller })
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
