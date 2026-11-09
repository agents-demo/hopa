import { StoredSettings } from './SettingsStore';

/**
 * Five modes, one app.
 *
 * A profile is a bundle of switches that already exist plus a few new ones:
 * look, density, input, guidance, confirmation, language, discovery, sharing
 * and the guardian guard. Applying one always leaves payments on the
 * confirmation path.
 */
export class ProfileService {
  static readonly KEY: string = 'hopa.profile';
  static readonly NAMES: string[] = ['everyday', 'easy', 'power', 'social', 'kid'];
  static readonly LABELS: string[] = ['Everyday', 'Easy', 'Power', 'Social', 'Kid'];

  name: string = 'everyday';
  style: string = 'calm';
  density: string = 'comfortable';
  input: string = 'mixed';
  guidance: string = 'summary';
  confirm: string = 'risky';
  language: string = 'concise';
  discovery: string = 'guided';
  sharing: string = 'receipt';
  guardian: boolean = false;

  static of(name: string): ProfileService {
    const profile = new ProfileService();
    profile.name = ProfileService.NAMES.indexOf(name) >= 0 ? name : 'everyday';
    if (profile.name === 'easy') {
      profile.style = 'easy';
      profile.input = 'voice';
      profile.guidance = 'explain';
      profile.confirm = 'always';
      profile.language = 'plain';
      profile.discovery = 'guided';
      profile.sharing = 'receipt';
      profile.density = 'comfortable';
    } else if (profile.name === 'power') {
      profile.style = 'calm';
      profile.density = 'compact';
      profile.input = 'type';
      profile.guidance = 'silent';
      profile.confirm = 'risky';
      profile.language = 'concise';
      profile.discovery = 'command';
      profile.sharing = 'receipt';
    } else if (profile.name === 'social') {
      profile.style = 'vivid';
      profile.input = 'mixed';
      profile.guidance = 'summary';
      profile.confirm = 'risky';
      profile.language = 'playful';
      profile.discovery = 'guided';
      profile.sharing = 'recap';
    } else if (profile.name === 'kid') {
      profile.style = 'vivid';
      profile.input = 'voice';
      profile.guidance = 'explain';
      profile.confirm = 'always';
      profile.language = 'plain';
      profile.discovery = 'guided';
      profile.sharing = 'minimal';
      profile.guardian = true;
    }
    return profile;
  }

  static labelOf(name: string): string {
    const index: number = ProfileService.NAMES.indexOf(name);
    return index >= 0 ? ProfileService.LABELS[index] : ProfileService.LABELS[0];
  }

  static describe(name: string): string {
    if (name === 'easy') {
      return 'Bigger text, voice first, explains each step.';
    }
    if (name === 'power') {
      return 'Dense, quiet, keyboard first, fewer confirmations.';
    }
    if (name === 'social') {
      return 'Expressive, speaks answers, shares recaps.';
    }
    if (name === 'kid') {
      return 'No payments or posting; a grown-up sets this.';
    }
    return 'Balanced: calm look, brief steps, asks before risk.';
  }

  /** Writes the flags the rest of the app already understands. */
  applyTo(settings: StoredSettings): void {
    settings.profile = this.name;
    settings.style = this.style;
    settings.showSteps = this.guidance !== 'silent';
    settings.reduceMotion = this.name === 'easy' || this.name === 'kid';
    settings.speakReplies = this.name === 'easy' || this.name === 'social' || this.name === 'kid';
    settings.autonomous = this.name === 'power' || this.name === 'social' || this.name === 'everyday';
    settings.network = !this.guardian;
  }
}
