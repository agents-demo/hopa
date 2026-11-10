import { StoredSettings } from './SettingsStore';

/**
 * HOPA's voice: capable first, dry, adult.
 *
 * This is copy and timing only. There are no mascots, stickers or confetti;
 * Kid mode keeps its own playful tiles because that is a different audience.
 */
export class Character {
  static readonly TONES: string[] = ['warm', 'balanced', 'direct'];
  static readonly TONE_LABELS: string[] = ['Warm', 'Balanced', 'Direct'];
  static readonly CHATTER: string[] = ['quiet', 'balanced', 'chatty'];
  static readonly CHATTER_LABELS: string[] = ['Quiet', 'Balanced', 'Chatty'];

  static readonly PRINCIPLES: string[] = [
    'Do the thing first; the sentence comes after.',
    'Dry beats cute. No mascots, stickers or confetti.',
    'Warmth is timing and attention, not praise.',
    'Say what failed and what still works.',
    'Never claim an action HOPA did not take.'
  ];

  /** Persona state, mirrored into settings so it survives a restart. */
  static tone: string = 'warm';
  static chattiness: string = 'balanced';
  static quips: boolean = true;
  static tactile: boolean = true;
  /** What HOPA calls the user; empty means no name. */
  static address: string = '';
  /** System.Speech voice name on the PC; empty means the PC default. */
  static voice: string = '';

  static configure(stored: StoredSettings): void {
    Character.tone = Character.TONES.indexOf(stored.tone) >= 0 ? stored.tone : 'warm';
    Character.chattiness = Character.CHATTER.indexOf(stored.chattiness) >= 0
      ? stored.chattiness
      : 'balanced';
    Character.quips = stored.quips;
    Character.tactile = stored.tactile;
    Character.address = stored.address.trim();
    Character.voice = stored.voice;
  }

  static label(tone: string): string {
    const index: number = Character.TONES.indexOf(tone);
    return index >= 0 ? Character.TONE_LABELS[index] : Character.TONE_LABELS[0];
  }

  static chatterLabel(level: string): string {
    const index: number = Character.CHATTER.indexOf(level);
    return index >= 0 ? Character.CHATTER_LABELS[index] : Character.CHATTER_LABELS[1];
  }

  static greeting(hour: number): string {
    const name: string = Character.address.trim();
    if (Character.tone === 'direct') {
      return hour < 5 ? 'Late.' : (hour < 12 ? 'Morning.' : (hour < 18 ? 'Afternoon.' : 'Evening.'));
    }
    if (hour < 5) {
      return name.length > 0 ? `Still up, ${name}?` : 'Still up?';
    }
    const base: string = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Character.tone === 'warm' && name.length > 0 ? `${base}, ${name}` : base;
  }

  /** Keeps the promise line, but lets the tone tighten it. */
  static tagline(profile: string): string {
    if (profile === 'easy' || profile === 'kid') {
      return 'Type or say what you need. I will do it on this phone.';
    }
    if (profile === 'social') {
      return 'What are we doing today?';
    }
    if (Character.tone === 'direct') {
      return 'Your phone agent. Ask.';
    }
    return 'Your phone agent. Ask for anything.';
  }

  /**
   * One honest sentence for a failure, chosen from the real cause.
   * The raw error still goes to Settings, Logs.
   */
  static failure(raw: string, profile: string = 'everyday'): string {
    const low: string = raw.toLowerCase();
    if (low.includes('network') || low.includes('dns') || low.includes('unreachable') ||
      low.includes('no sim')) {
      return 'No network on the phone. Check Wi-Fi or mobile data, then ask again.';
    }
    if (low.includes('api key') || low.includes('unauthor') || low.includes('401') ||
      low.includes('model not') || low.includes('model refused')) {
      return 'The model refused the key. Fix it in Settings, Model. The rest of HOPA still works.';
    }
    if (low.includes('bridge')) {
      return 'The PC bridge stopped answering. Start it on the computer and I will retry.';
    }
    if (low.includes('timeout') || low.includes('timed out') || low.includes('too long')) {
      return 'That took too long, so I stopped. Try a smaller ask.';
    }
    if (profile === 'power' || Character.tone === 'direct') {
      return 'That did not work. Details in Settings, Logs.';
    }
    return 'That did not work. The details are in Settings, Logs.';
  }

  /** A dry line after a run, or '' when the user asked for quiet. */
  static quip(ok: boolean, steps: number, profile: string = 'everyday'): string {
    if (profile === 'easy' || profile === 'kid') {
      return '';
    }
    if (!Character.quips || Character.chattiness === 'quiet' || !ok) {
      return '';
    }
    if (Character.tone === 'direct') {
      return 'Done.';
    }
    if (steps >= 3) {
      return 'Done. That took a few taps.';
    }
    return steps > 1 ? 'Done. The phone did the rest.' : 'Done.';
  }

  /** One line for the step in progress, in the current voice. */
  static narrate(step: string): string {
    const low: string = step.toLowerCase();
    let line: string = 'Working.';
    if (low.includes('launch') || low.startsWith('opened')) {
      line = 'Opening the app.';
    } else if (low.includes('type')) {
      line = 'Typing.';
    } else if (low.includes('tap')) {
      line = 'Tapping where you asked.';
    } else if (low.includes('screenshot') || low.includes('observe') || low.includes('scroll')) {
      line = 'Reading the screen.';
    } else if (low.includes('wait')) {
      line = 'Waiting for the screen.';
    } else if (low.includes('speak') || low.includes('transcrib')) {
      line = 'Listening.';
    }
    if (Character.tone === 'direct') {
      return line;
    }
    if (Character.chattiness === 'chatty' && line !== 'Working.') {
      return `${line} One moment.`;
    }
    return line;
  }

  /** The live example shown in the persona sheet. */
  static sample(): string {
    if (Character.tone === 'direct') {
      return 'Done. Top three on screen.';
    }
    if (Character.tone === 'balanced') {
      return 'Opened Weibo. The top three are on screen.';
    }
    return 'Opened Weibo and stopped at the top three. Want them read aloud?';
  }
}
