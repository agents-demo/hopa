import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';

/**
 * One ongoing notification while HOPA works, so the agent stays visible when
 * the user is in another app. It is updated in place and removed at the end.
 */
export class RunNotification {
  private static readonly ID: number = 1001;
  private static allowed: boolean = false;
  private static asked: boolean = false;
  private static active: boolean = false;

  private static async ensure(context: common.UIAbilityContext): Promise<void> {
    if (RunNotification.asked) {
      return;
    }
    RunNotification.asked = true;
    try {
      await notificationManager.requestEnableNotification(context);
      RunNotification.allowed = true;
    } catch (error) {
      RunNotification.allowed = false;
    }
  }

  static async start(context: common.UIAbilityContext, goal: string): Promise<void> {
    await RunNotification.ensure(context);
    if (!RunNotification.allowed) {
      return;
    }
    RunNotification.active = true;
    await RunNotification.publish('HOPA is working', goal.length > 0 ? goal : 'On it');
  }

  static async update(step: string): Promise<void> {
    if (!RunNotification.allowed || !RunNotification.active || step.length === 0) {
      return;
    }
    await RunNotification.publish('HOPA is working', step);
  }

  static async stop(): Promise<void> {
    if (!RunNotification.allowed || !RunNotification.active) {
      return;
    }
    RunNotification.active = false;
    try {
      await notificationManager.cancel(RunNotification.ID);
    } catch (error) {
      // Already gone.
    }
  }

  private static async publish(title: string, text: string): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: RunNotification.ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
            additionalText: 'HOPA'
          }
        },
        isOngoing: true,
        isUnremovable: true,
        tapDismissed: false
      };
      await notificationManager.publish(request);
    } catch (error) {
      // A denied or unsupported notification must never stop a run.
    }
  }
}
