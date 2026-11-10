import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { AppLauncher } from './AppLauncher';
import { AgentService } from './AgentService';
import { Appearance } from './Appearance';
import { SettingsStore, StoredSettings } from './SettingsStore';
import { KeyStore } from './KeyStore';
import { BridgeSessionStore } from './BridgeSessionStore';

/**
 * App startup: saved settings, the bundled development key, and the stores.
 *
 * Kept out of the shell so the page file stays about layout and navigation.
 */
export class AppBoot {
  /** Configures the app and returns true on the first run. */
  static async start(service: AgentService, context: common.UIAbilityContext): Promise<boolean> {
    await AppBoot.applySettings(service, context);
    await AppBoot.loadStores(service, context);
    service.setUiLauncher(new AppLauncher(context));
    const firstRun: boolean = await SettingsStore.needsWelcome(context);
    if (firstRun) {
      await SettingsStore.markWelcomeSeen(context);
    }
    return firstRun;
  }

  private static async applySettings(
    service: AgentService,
    context: common.UIAbilityContext
  ): Promise<void> {
    let stored: StoredSettings = new StoredSettings();
    try {
      stored = await SettingsStore.load(context);
      service.setNetworkEnabled(stored.network);
      service.setAutonomous(stored.autonomous);
      service.restoreLastUsage(stored.lastTokens, stored.lastDurationMs);
      Appearance.apply(context, stored.appearance);
      if (stored.bridgeUrl.length > 0) {
        const session = await BridgeSessionStore.load();
        if (session.token.length > 0) {
          if (session.refresh.length > 0) {
            service.configureBridgeSession(stored.bridgeUrl, session.token, session.refresh);
          } else {
            service.configureBridge(stored.bridgeUrl, session.token);
          }
        } else if (stored.bridgeToken.length > 0) {
          // A pre-rotation install: works until that token expires, then the
          // setup wizard issues a paired session.
          service.configureBridge(stored.bridgeUrl, stored.bridgeToken);
        }
      }
    } catch (error) {
      // First run or an unreadable store: keep the defaults.
    }
    let key: string = '';
    try {
      key = await KeyStore.load();
    } catch (error) {
      key = '';
    }
    if (key.length < 10) {
      // Migration path: a dev build may still carry the bundled key. Move it
      // into secure storage so later builds can ship without it.
      try {
        const data = await context.resourceManager.getRawFileContent('deepseek.key');
        const bundled = buffer.from(data).toString('utf8').trim();
        if (bundled.length >= 10) {
          key = bundled;
          await KeyStore.save(key);
        }
      } catch (error) {
        // No bundled key: a normal first run.
      }
    }
    if (key.length >= 10) {
      service.configureModel(
        'deepseek',
        'https://api.deepseek.com/v1',
        key,
        'deepseek-v4-flash',
        14
      );
      // Keep the Settings form in step with the model that is actually active.
      if (stored.provider !== 'deepseek' ||
        stored.endpoint !== 'https://api.deepseek.com/v1' ||
        stored.model !== 'deepseek-v4-flash') {
        stored.provider = 'deepseek';
        stored.endpoint = 'https://api.deepseek.com/v1';
        stored.model = 'deepseek-v4-flash';
        await SettingsStore.save(context, stored);
      }
    }
  }

  private static async loadStores(
    service: AgentService,
    context: common.UIAbilityContext
  ): Promise<void> {
    try {
      await service.memory.load(context);
    } catch (error) {
      // First run: no memory yet.
    }
    try {
      await service.skills.load(context);
    } catch (error) {
      // First run: no skills yet.
    }
    try {
      await service.loadRuns(context);
    } catch (error) {
      // First run: no history yet.
    }
    try {
      await service.scheduleService.load(context);
      service.scheduleService.start();
    } catch (error) {
      // Schedules are optional.
    }
  }
}
