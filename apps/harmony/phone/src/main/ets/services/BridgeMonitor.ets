import { AgentService } from './AgentService';

/**
 * Keeps one boolean in AppStorage: is the configured PC bridge answering?
 *
 * A lost reverse port used to look like a model failure; the shell can now show
 * "PC bridge offline" and offer a retry.
 */
export class BridgeMonitor {
  private static timer: number = -1;
  private static checking: boolean = false;

  static start(): void {
    if (BridgeMonitor.timer >= 0) {
      return;
    }
    BridgeMonitor.checkNow();
    BridgeMonitor.timer = setInterval(() => {
      BridgeMonitor.checkNow();
    }, 15000);
  }

  static stop(): void {
    if (BridgeMonitor.timer >= 0) {
      clearInterval(BridgeMonitor.timer);
      BridgeMonitor.timer = -1;
    }
  }

  static async checkNow(): Promise<boolean> {
    const service = AgentService.get();
    if (!service.isBridgeConfigured()) {
      AppStorage.setOrCreate<boolean>('hopa.bridgeOnline', true);
      return true;
    }
    if (BridgeMonitor.checking) {
      return true;
    }
    BridgeMonitor.checking = true;
    const ok: boolean = await service.bridge.health();
    BridgeMonitor.checking = false;
    AppStorage.setOrCreate<boolean>('hopa.bridgeOnline', ok);
    AppStorage.setOrCreate<boolean>('hopa.bridgeTunnelKnown', service.bridge.tunnelIsReported());
    AppStorage.setOrCreate<boolean>('hopa.bridgeDeviceReady', service.bridge.tunnelIsReady());
    return ok;
  }
}
