import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { AppLauncher } from './AppLauncher';
import { AgentService } from './AgentService';
import { Appearance } from './Appearance';
import { SettingsStore, StoredSettings } from './SettingsStore';

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
      Appearance.apply(context, stored.appearance);
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        service.configureBridge(stored.bridgeUrl, stored.bridgeToken);
      }
    } catch (error) {
      // First run or an unreadable store: keep the defaults.
    }
    try {
      const data = await context.resourceManager.getRawFileContent('deepseek.key');
      const key = buffer.from(data).toString('utf8').trim();
      if (key.length >= 10) {
        service.configureModel(
          'deepseek',
          'https://api.deepseek.com/v1',
          key,
          'deepseek-v4-flash',
          6
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
    } catch (error) {
      // No bundled key: a normal first run.
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
