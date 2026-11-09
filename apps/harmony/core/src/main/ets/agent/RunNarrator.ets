import { ActionOutcome } from '../Types';

/**
 * Turns executed actions into a short, human reply for the chat.
 *
 * The raw action transcript still goes to the run record and to "Continue last
 * task"; this class is only for what the user reads.
 */
export class RunNarrator {
  static summarize(outcomes: ActionOutcome[], names: Map<string, string>): string {
    const done: string[] = [];
    let taps: number = 0;
    const flushTaps = (): void => {
      if (taps > 0) {
        done.push(taps === 1 ? 'Tapped a control.' : `Tapped ${taps} controls.`);
        taps = 0;
      }
    };
    for (const outcome of outcomes) {
      if (!outcome.executed || !outcome.observation.success) {
        return RunNarrator.failure(outcome, names);
      }
      const kind: string = outcome.action.kind;
      if (kind === 'ui.tap' || kind === 'ui.doubleTap' || kind === 'ui.longPress') {
        taps += 1;
        continue;
      }
      flushTaps();
      done.push(RunNarrator.line(outcome, names));
    }
    flushTaps();
    if (done.length === 0) {
      return 'Done.';
    }
    return done.join(' ');
  }

  private static line(outcome: ActionOutcome, names: Map<string, string>): string {
    const kind: string = outcome.action.kind;
    if (kind === 'ui.launch') {
      return `Opened ${RunNarrator.displayName(outcome.action.app, names)}.`;
    }
    if (kind === 'ui.type') {
      const text: string = outcome.action.text.trim();
      if (text.length === 0) {
        return 'Typed the text.';
      }
      const shown: string = text.length > 40 ? `${text.substring(0, 40)}...` : text;
      return `Typed “${shown}”.`;
    }
    if (kind === 'ui.swipe' || kind === 'ui.scroll') {
      return 'Scrolled the screen.';
    }
    if (kind === 'ui.back') {
      return 'Went back.';
    }
    if (kind === 'ui.home') {
      return 'Went to the home screen.';
    }
    if (kind === 'web.navigate') {
      return `Opened ${outcome.action.url}.`;
    }
    if (kind === 'web.read') {
      return 'Read the page.';
    }
    if (kind === 'web.click') {
      return `Clicked “${outcome.action.target}”.`;
    }
    if (kind === 'web.type') {
      return 'Typed into the page.';
    }
    if (kind === 'sandbox.run') {
      return 'Ran the script.';
    }
    return 'Finished that step.';
  }

  private static failure(outcome: ActionOutcome, names: Map<string, string>): string {
    const detail: string = outcome.observation.detail.length > 0
      ? outcome.observation.detail
      : outcome.observation.summary;
    if (!outcome.executed) {
      return detail.length > 0 ? `I stopped: ${detail}` : 'I stopped before that step.';
    }
    if (outcome.action.kind === 'ui.launch') {
      const name: string = RunNarrator.displayName(outcome.action.app, names);
      return detail.length > 0
        ? `I couldn't open ${name}: ${detail}`
        : `I couldn't open ${name}.`;
    }
    return detail.length > 0
      ? `I couldn't finish that step: ${detail}`
      : "I couldn't finish that step.";
  }

  private static displayName(bundle: string, names: Map<string, string>): string {
    const display: string | undefined = names.get(bundle.toLowerCase());
    return display === undefined || display.length === 0 ? bundle : display;
  }
}
