import { AgentService } from '../../services/AgentService';

/** Live device screen through the PC bridge, refreshed every 3 seconds. */
@Component
export struct ScreensPage {
  @State screenImage: string = '';
  @State screenStatus: string = 'not loaded';
  @State liveView: boolean = true;
  private timer: number = -1;

  aboutToAppear(): void {
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.stopPolling();
  }

  private startPolling(): void {
    if (this.timer >= 0) {
      return;
    }
    if (!AgentService.get().isBusy()) {
      this.refresh();
    }
    this.timer = setInterval(() => {      // A live frame is nice, but the agent needs hdc more: do not compete
      // with an observe/tap while a run is in progress.
      if (this.liveView && !AgentService.get().isBusy()) {
        this.refresh();
      }
    }, 3000);
  }

  private stopPolling(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private async refresh(): Promise<void> {
    if (!AgentService.get().isBridgeConfigured()) {
      this.screenStatus = 'bridge not configured';
      return;
    }
    if (this.screenStatus === 'loading...') {
      return;
    }
    this.screenStatus = 'loading...';
    const image: string = await AgentService.get().bridge.screenshot();
    if (image.length === 0) {
      this.screenStatus = 'no frame (bridge unreachable)';
      return;
    }
    this.screenImage = image;
    this.screenStatus = `updated ${new Date().toLocaleTimeString()}`;
  }

  build() {
    Column({ space: 10 }) {
      Text(AgentService.get().isBridgeConfigured()
        ? 'A debug mirror of this phone through the PC bridge. Useful to check what HOPA captured, not needed for normal use.'
        : 'Connect the PC bridge in Settings if you want this diagnostic mirror. Normal tasks do not need it.')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      if (this.screenImage.length > 0) {
        Image(this.screenImage)
          .width('100%')
          .layoutWeight(1)
          .objectFit(ImageFit.Contain)
          .borderRadius(8)
      } else {
        Text('No frame yet.')
          .fontSize(12)
          .fontColor($r('app.color.text_hint'))
      }
      Row({ space: 8 }) {
        Button('Refresh')
          .fontSize(12)
          .onClick(() => {
            this.refresh();
          })
        Toggle({ type: ToggleType.Switch, isOn: this.liveView })
          .onChange((on: boolean) => {
            this.liveView = on;
            if (on) {
              this.startPolling();
            } else {
              this.stopPolling();
            }
          })
        Text('Live')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        Text(this.screenStatus)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
