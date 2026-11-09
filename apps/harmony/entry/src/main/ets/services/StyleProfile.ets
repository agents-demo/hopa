/**
 * Three looks for three kinds of users.
 *
 * Calm is the default; Easy trades density for legibility and bigger targets;
 * Vivid leans into the mascot and rounder shapes. Each profile only changes
 * tokens the app already uses, so switching never needs a restart.
 */
export class StyleProfile {
  static readonly KEY: string = 'hopa.style';
  static readonly NAMES: string[] = ['calm', 'easy', 'vivid'];
  static readonly LABELS: string[] = ['Calm', 'Easy', 'Vivid'];

  name: string = 'calm';
  bg: string = '#F7F4EE';
  cardRadius: number = 12;
  bubbleRadius: number = 18;
  body: number = 15;
  title: number = 27;
  mascot: number = 72;
  composerHeight: number = 42;
  composerFont: number = 15;
  buttonSize: number = 36;
  motion: boolean = true;

  static of(name: string): StyleProfile {
    const style = new StyleProfile();
    style.name = name;
    if (name === 'easy') {
      style.bg = '#FFFCF3';
      style.cardRadius = 16;
      style.bubbleRadius = 20;
      style.body = 17;
      style.title = 31;
      style.mascot = 88;
      style.composerHeight = 48;
      style.composerFont = 17;
      style.buttonSize = 40;
      style.motion = false;
    } else if (name === 'vivid') {
      style.bg = '#F4EEFF';
      style.cardRadius = 22;
      style.bubbleRadius = 24;
      style.body = 15;
      style.title = 27;
      style.mascot = 78;
      style.composerHeight = 42;
      style.composerFont = 15;
      style.buttonSize = 38;
      style.motion = true;
    }
    return style;
  }

  static labelOf(name: string): string {
    if (name === 'easy') {
      return 'Easy';
    }
    if (name === 'vivid') {
      return 'Vivid';
    }
    return 'Calm';
  }
}
