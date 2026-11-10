import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { VoiceService } from '@hopa/app';
import { LaptopAgent } from './LaptopAgent';

/**
 * Voice on the laptop.
 *
 * The 2in1 has a microphone but no speech engine, so the same split the phone
 * uses applies: record 16 kHz mono here, let the PC bridge transcribe, and let
 * the bridge synthesise the reply. Without a bridge, voice is off and the mic
 * button says so instead of pretending to listen.
 */
export class LaptopVoice {
  private voice: VoiceService = new VoiceService();
  private active: boolean = false;

  isRecording(): boolean {
    return this.active;
  }

  async start(context: common.UIAbilityContext): Promise<boolean> {
    if (this.active) {
      return true;
    }
    try {
      const manager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = ['ohos.permission.MICROPHONE'];
      const result = await manager.requestPermissionsFromUser(context, permissions);
      const allowed: boolean = result.authResults.length > 0 && result.authResults[0] === 0;
      if (!allowed) {
        return false;
      }
      await this.voice.start();
      this.active = true;
      return true;
    } catch (error) {
      this.active = false;
      return false;
    }
  }

  /** Stop, transcribe on the PC, and return what it heard ('' when unclear). */
  async stop(agent: LaptopAgent): Promise<string> {
    if (!this.active) {
      return '';
    }
    this.active = false;
    let wav: ArrayBuffer = new ArrayBuffer(0);
    try {
      wav = await this.voice.stop();
    } catch (error) {
      wav = new ArrayBuffer(0);
    }
    if (wav.byteLength <= 44 || !agent.isBridgeConfigured()) {
      return '';
    }
    try {
      const helper: util.Base64Helper = new util.Base64Helper();
      const heard: string = await agent.bridge.transcribe(
        helper.encodeToStringSync(new Uint8Array(wav)));
      return heard.trim();
    } catch (error) {
      return '';
    }
  }

  async cancel(): Promise<void> {
    this.active = false;
    await this.voice.cancel();
  }

  /** Speak an answer through the laptop's own speaker. */
  async speak(agent: LaptopAgent, text: string, context: common.UIAbilityContext): Promise<void> {
    if (text.trim().length === 0 || !agent.isBridgeConfigured()) {
      return;
    }
    try {
      const encoded: string = await agent.bridge.speak(text);
      if (encoded.length === 0) {
        return;
      }
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = helper.decodeSync(encoded);
      const wav: ArrayBuffer = bytes.buffer as ArrayBuffer;
      await this.voice.speak(wav, context);
    } catch (error) {
      // Silence is better than a failed run.
    }
  }

  async release(): Promise<void> {
    await this.voice.releasePlayer();
  }
}
