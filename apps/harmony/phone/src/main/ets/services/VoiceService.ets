import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';

/**
 * Voice in and out.
 *
 * This SDK has no Speech Kit, so the phone records 16 kHz mono PCM and lets
 * the PC bridge transcribe it; replies are synthesised on the PC and played
 * through the phone's own speaker.
 */
export class VoiceService {
  private capturer: audio.AudioCapturer | undefined = undefined;
  private chunks: ArrayBuffer[] = [];
  private reading: boolean = false;
  private player: media.AVPlayer | undefined = undefined;
  private playerPath: string = '';

  isRecording(): boolean {
    return this.capturer !== undefined;
  }

  async start(): Promise<void> {
    this.chunks = [];
    const options: audio.AudioCapturerOptions = {
      streamInfo: {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      },
      capturerInfo: {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    };
    const capturer = await audio.createAudioCapturer(options);
    await capturer.start();
    this.capturer = capturer;
    this.reading = true;
    this.pump();
  }

  private pump(): void {
    const capturer = this.capturer;
    if (capturer === undefined || !this.reading) {
      return;
    }
    capturer.read(3200, true).then((data: ArrayBuffer) => {
      if (this.reading) {
        this.chunks.push(data);
        this.pump();
      }
    }).catch(() => {
      this.reading = false;
    });
  }

  /** Stop, release the mic and return a complete WAV (empty when too short). */
  async stop(): Promise<ArrayBuffer> {
    this.reading = false;
    const capturer = this.capturer;
    this.capturer = undefined;
    if (capturer !== undefined) {
      try {
        await capturer.stop();
      } catch (error) {
        // Already stopped: nothing to do.
      }
      try {
        await capturer.release();
      } catch (error) {
        // Already released.
      }
    }
    return this.toWav();
  }

  async cancel(): Promise<void> {
    this.reading = false;
    this.chunks = [];
    const capturer = this.capturer;
    this.capturer = undefined;
    if (capturer !== undefined) {
      try {
        await capturer.stop();
      } catch (error) {
        // Already stopped.
      }
      try {
        await capturer.release();
      } catch (error) {
        // Already released.
      }
    }
  }

  private toWav(): ArrayBuffer {
    let dataLength: number = 0;
    for (const chunk of this.chunks) {
      dataLength += chunk.byteLength;
    }
    if (dataLength === 0) {
      return new ArrayBuffer(0);
    }
    const wav = new Uint8Array(44 + dataLength);
    this.writeString(wav, 0, 'RIFF');
    this.writeUint32(wav, 4, 36 + dataLength);
    this.writeString(wav, 8, 'WAVE');
    this.writeString(wav, 12, 'fmt ');
    this.writeUint32(wav, 16, 16);
    this.writeUint16(wav, 20, 1);
    this.writeUint16(wav, 22, 1);
    this.writeUint32(wav, 24, 16000);
    this.writeUint32(wav, 28, 32000);
    this.writeUint16(wav, 32, 2);
    this.writeUint16(wav, 34, 16);
    this.writeString(wav, 36, 'data');
    this.writeUint32(wav, 40, dataLength);
    let offset: number = 44;
    for (const chunk of this.chunks) {
      wav.set(new Uint8Array(chunk), offset);
      offset += chunk.byteLength;
    }
    this.chunks = [];
    return wav.buffer as ArrayBuffer;
  }

  private writeString(target: Uint8Array, offset: number, value: string): void {
    for (let index = 0; index < value.length; index++) {
      target[offset + index] = value.charCodeAt(index);
    }
  }

  private writeUint32(target: Uint8Array, offset: number, value: number): void {
    target[offset] = value & 0xff;
    target[offset + 1] = (value >> 8) & 0xff;
    target[offset + 2] = (value >> 16) & 0xff;
    target[offset + 3] = (value >> 24) & 0xff;
  }

  private writeUint16(target: Uint8Array, offset: number, value: number): void {
    target[offset] = value & 0xff;
    target[offset + 1] = (value >> 8) & 0xff;
  }

  /** Play WAV bytes from the bridge through the phone speaker. */
  async speak(wav: ArrayBuffer, context: Context): Promise<void> {
    if (wav.byteLength === 0) {
      return;
    }
    await this.releasePlayer();
    const path: string = `${context.filesDir}/hopa-reply.wav`;
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, wav);
    } finally {
      fs.closeSync(file);
    }
    const player = await media.createAVPlayer();
    this.player = player;
    this.playerPath = path;
    player.on('stateChange', (state: media.AVPlayerState) => {
      if (state === 'prepared') {
        player.play();
      } else if (state === 'completed') {
        this.releasePlayer();
      }
    });
    player.on('error', () => {
      this.releasePlayer();
    });
    player.url = `file://${path}`;
  }

  async releasePlayer(): Promise<void> {
    const player = this.player;
    this.player = undefined;
    if (player !== undefined) {
      try {
        await player.stop();
      } catch (error) {
        // Not playing.
      }
      try {
        await player.release();
      } catch (error) {
        // Already released.
      }
    }
  }
}
