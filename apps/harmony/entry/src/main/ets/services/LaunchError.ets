/**
 * Turns a HarmonyOS start-ability error into a sentence a user can act on.
 *
 * The raw BusinessError code is still logged; this only changes the message the
 * chat shows. Both launch paths (local UI context and PC bridge) use it.
 */
export class LaunchError {
  static describe(message: string): string {
    if (message.includes('16000001') || message.includes('16000019')) {
      return 'not installed on this device, or the ability name is wrong';
    }
    if (message.includes('16000018')) {
      return 'the system refused to open another app from HOPA';
    }
    if (message.includes('START_ABILITIES_FROM_BACKGROUND')) {
      return 'HOPA is in the background; connect the PC bridge to launch apps from here';
    }
    return message;
  }
}
