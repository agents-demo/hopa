import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { AgentService } from './AgentService';
import { VoiceService } from './VoiceService';

/**
 * One place for microphone capture, transcription and spoken replies.
 *
 * The UI owns the `recording` flag; this controller owns the device work so
 * Chat, Easy and Kid cannot drift apart.
 */
export class VoiceController {
  private voice: VoiceService = new VoiceService();
  private active: boolean = false;

  isRecording(): boolean {
    return this.active;
  }

  /** Ask for the mic, then start recording. False when denied or unavailable. */
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

  /** Stop, transcribe on the PC and return the heard text ('' when unclear). */
  async stop(): Promise<string> {
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
    if (wav.byteLength <= 44) {
      return '';
    }
    const service = AgentService.get();
    if (!service.isBridgeConfigured()) {
      return '';
    }
    try {
      const helper: util.Base64Helper = new util.Base64Helper();
      const heard: string = await service.bridge.transcribe(
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

  /** Synthesise on the PC and play through the phone speaker. */
  async speak(text: string, context: common.UIAbilityContext): Promise<void> {
    const service = AgentService.get();
    const spoken: string = text.trim();
    if (!service.isBridgeConfigured() || spoken.length === 0) {
      return;
    }
    try {
      const audio: string = await service.bridge.speak(spoken.substring(0, 600));
      if (audio.length === 0) {
        return;
      }
      const helper: util.Base64Helper = new util.Base64Helper();
      const bytes: Uint8Array = helper.decodeSync(audio);
      const wav: ArrayBuffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
      await this.voice.speak(wav, context);
    } catch (error) {
      // Speaking is optional; never interrupt the answer.
    }
  }

  release(): void {
    this.voice.releasePlayer();
  }
}
