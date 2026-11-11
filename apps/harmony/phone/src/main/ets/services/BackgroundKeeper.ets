import { RuntimeBackground } from '@hopa/app';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Keeps one agent run alive while the controlled app is in the foreground.
 *
 * HarmonyOS suspends a normal app shortly after it leaves the foreground, which
 * would freeze the loop between "launch" and the next "observe". A continuous
 * task of type `dataTransfer` is the generic, user-visible way to stay alive:
 * the system shows its own notification while the task runs.
 *
 * This is best effort. If the permission is denied, the run still works while
 * HOPA is foreground; it simply may not survive the switch.
 */
export class BackgroundKeeper implements RuntimeBackground {
  private context: common.UIAbilityContext | undefined = undefined;
  private running: boolean = false;
  private agent: WantAgent | undefined = undefined;

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  isRunning(): boolean {
    return this.running;
  }

  async begin(): Promise<void> {
    if (this.running || this.context === undefined) {
      return;
    }
    const context: common.UIAbilityContext = this.context;
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: context.abilityInfo.bundleName,
            abilityName: context.abilityInfo.name
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      this.agent = agent;
      await backgroundTaskManager.startBackgroundRunning(
        context,
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        agent
      );
      this.running = true;
      hilog.info(0x0000, 'HOPA', 'background: continuous task started');
    } catch (error) {
      this.running = false;
      hilog.warn(0x0000, 'HOPA', `background: continuous task refused ${error}`);
    }
  }

  /**
   * Brings HOPA back in front after the loop operated another app.
   *
   * `startAbility` is called while the continuous task still runs, which lets a
   * background app start its own UIAbility. If the system still refuses it,
   * trigger the continuous-task notification's WantAgent, which is allowed to
   * start the ability from the notification.
   */
  async returnToForeground(): Promise<boolean> {
    const context = this.context;
    if (context === undefined) {
      return false;
    }
    try {
      await context.startAbility({
        bundleName: context.abilityInfo.bundleName,
        abilityName: context.abilityInfo.name
      });
      hilog.info(0x0000, 'HOPA', 'focus: returned to HOPA');
      return true;
    } catch (error) {
      hilog.warn(0x0000, 'HOPA', `focus: startAbility failed ${error}`);
    }
    if (this.agent !== undefined) {
      const agent: WantAgent = this.agent;
      try {
        const triggered: boolean = await new Promise<boolean>((resolve: (value: boolean) => void) => {
          wantAgent.trigger(agent, { code: 0 }, (err: BusinessError) => {
            if (err) {
              hilog.warn(0x0000, 'HOPA', `focus: notification agent failed ${err.message}`);
              resolve(false);
            } else {
              hilog.info(0x0000, 'HOPA', 'focus: triggered the notification agent');
              resolve(true);
            }
          });
        });
        if (triggered) {
          return true;
        }
      } catch (error) {
        hilog.warn(0x0000, 'HOPA', `focus: wantAgent trigger failed ${error}`);
      }
    }
    return false;
  }

  async end(): Promise<void> {
    if (!this.running || this.context === undefined) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      hilog.info(0x0000, 'HOPA', 'background: continuous task stopped');
    } catch (error) {
      hilog.warn(0x0000, 'HOPA', `background: stop failed ${error}`);
    }
    this.running = false;
  }
}
