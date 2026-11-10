import { Context } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { AgentService } from '../../services/AgentService';
import { BridgeClient } from '../../services/BridgeClient';
import { SettingsStore, StoredSettings } from '../../services/SettingsStore';

/** Three steps from "nothing" to a paired PC bridge. */
@Component
export struct BridgeWizard {
  onDone: () => void = () => {};
  @State step: number = 1;
  @State url: string = 'http://127.0.0.1:8766';
  @State code: string = '';
  @State token: string = '';
  @State status: string = '';
  @State busy: boolean = false;
  @State voices: number = 0;
  @State reachable: boolean = false;
  private bridge: BridgeClient = new BridgeClient();

  private static readonly COMMAND: string =
    'python -m hopa_pc_agent bridge --host 127.0.0.1 --port 8766';

  aboutToAppear(): void {
    SettingsStore.load(getContext(this) as Context).then((stored: StoredSettings) => {
      if (stored.bridgeUrl.length > 0) {
        this.url = stored.bridgeUrl;
      }
      if (stored.bridgeToken.length > 0) {
        this.token = stored.bridgeToken;
        this.bridge.configure(this.url, this.token);
        this.check();
      }
    }).catch(() => {
      // Defaults are fine.
    });
  }

  private toast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }

  private copyCommand(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, BridgeWizard.COMMAND);
      pasteboard.getSystemPasteboard().setData(data).then(() => {
        this.toast('Command copied');
      }).catch(() => {});
    } catch (error) {
      this.toast('Could not copy');
    }
  }

  private async pair(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.code.trim().length === 0 || this.url.trim().length === 0) {
      this.status = 'Enter the address and the code shown on the PC.';
      return;
    }
    this.busy = true;
    this.status = 'Pairing...';
    try {
      const token: string = await BridgeClient.pair(this.url, this.code.trim());
      this.token = token;
      AgentService.get().configureBridge(this.url, token);
      const context = getContext(this) as Context;
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.bridgeUrl = this.url;
      stored.bridgeToken = token;
      await SettingsStore.save(context, stored);
      this.bridge.configure(this.url, token);
      this.status = '';
      this.reachable = true;
      this.step = 3;
      this.check();
    } catch (error) {
      this.status = 'That code did not work. Check it on the PC and try again.';
    }
    this.busy = false;
  }

  private async check(): Promise<void> {
    const ok: boolean = await this.bridge.health();
    if (!ok) {
      this.reachable = false;
      this.status = 'Paired, but the bridge did not answer. Check the address, then pair again.';
      return;
    }
    this.reachable = true;
    this.status = '';
    const voices: string[] = await this.bridge.voices();
    this.voices = voices.length;
    this.step = 3;
    this.status = '';
  }

  @Builder
  StepDots() {
    Row({ space: 6 }) {
      ForEach([1, 2, 3], (dot: number) => {
        Circle({ width: 7, height: 7 })
          .fill(dot <= this.step ? $r('app.color.primary') : $r('app.color.divider'))
      }, (dot: number) => `${dot}`)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  StepOne() {
    Column({ space: 12 }) {
      Text('Start the bridge on the computer')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('On the PC, in the HOPA repo, run this. It prints a six-digit code and a token.')
        .fontSize(12.5)
        .lineHeight(19)
        .fontColor($r('app.color.text_secondary'))
      Text(BridgeWizard.COMMAND)
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding(10)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(10)
      Row({ space: 8 }) {
        Text('Copy command')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.primary'))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor($r('app.color.primary_soft'))
          .borderRadius(10)
          .onClick(() => {
            this.copyCommand();
          })
      }
      .width('100%')
      Text('I started it')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
        .width('100%')
        .height(48)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(12)
        .onClick(() => {
          this.step = 2;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StepTwo() {
    Column({ space: 12 }) {
      Text('Pair this phone')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('Use the address the bridge listens on and the six-digit code it printed.')
        .fontSize(12.5)
        .lineHeight(19)
        .fontColor($r('app.color.text_secondary'))
      TextInput({ text: this.url, placeholder: 'http://192.168.1.10:8766' })
        .height(44)
        .fontSize(13)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(10)
        .onChange((value: string) => {
          this.url = value;
        })
      TextInput({ text: this.code, placeholder: 'six-digit pair code' })
        .height(44)
        .fontSize(15)
        .type(InputType.Number)
        .maxLength(6)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(10)
        .onChange((value: string) => {
          this.code = value;
        })
      Text(this.busy ? 'Pairing...' : 'Pair')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
        .width('100%')
        .height(48)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.busy ? $r('app.color.surface_muted') : $r('app.color.primary'))
        .borderRadius(12)
        .onClick(() => {
          this.pair();
        })
      Text('No QR code and no cloud account: the code is the whole handshake.')
        .fontSize(10)
        .fontColor($r('app.color.text_hint'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StepThree() {
    Column({ space: 12 }) {
      Text(this.reachable ? 'Connected' : 'Paired, no answer')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.reachable ? $r('app.color.success') : $r('app.color.warning'))
      Text(this.url)
        .fontSize(11)
        .fontColor($r('app.color.text_hint'))
      Text(this.reachable
        ? 'The phone can now be driven from the PC. Payments still ask on this phone.'
        : 'The code was accepted, but the health check failed. Pair again with the address the bridge prints.')
        .fontSize(12.5)
        .lineHeight(19)
        .fontColor($r('app.color.text_secondary'))
      if (this.reachable) {
        Text(this.voices > 0
          ? `${this.voices} speaking voices available`
          : 'No PC voices reported; spoken answers stay off.')
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
      }
      Text('Done')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_primary'))
        .width('100%')
        .height(48)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.primary'))
        .borderRadius(12)
        .onClick(() => {
          this.onDone();
        })
      Text('Pair again')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .height(42)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.surface_muted'))
        .borderRadius(12)
        .onClick(() => {
          this.code = '';
          this.status = '';
          this.step = 2;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        Text('\u2190')
          .fontSize(22)
          .fontColor($r('app.color.text_primary'))
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.onDone();
          })
        Text('PC bridge setup')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      this.StepDots()
      if (this.step === 1) {
        this.StepOne()
      } else if (this.step === 2) {
        this.StepTwo()
      } else {
        this.StepThree()
      }
      if (this.status.length > 0) {
        Text(this.status)
          .fontSize(11.5)
          .fontColor($r('app.color.warning'))
          .width('100%')
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 32, bottom: 20 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
