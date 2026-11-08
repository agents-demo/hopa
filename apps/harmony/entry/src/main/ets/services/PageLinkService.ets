import { ActionOutcome } from '@hopa/core';
import { BrowserController } from './BrowserController';

/**
 * The page a web task read, plus the opener that shows it again from Chat.
 *
 * The runtime records the URL/title; the UI supplies the opener that switches
 * to the Browser page. One concern, one file.
 */
export class PageLinkService {
  private lastUrl: string = '';
  private lastTitle: string = '';
  private opener: ((url: string) => void) | undefined = undefined;

  clear(): void {
    this.lastUrl = '';
    this.lastTitle = '';
  }

  url(): string {
    return this.lastUrl;
  }

  title(): string {
    return this.lastTitle;
  }

  setOpener(opener: (url: string) => void): void {
    this.opener = opener;
  }

  open(url: string): void {
    if (this.opener !== undefined && url.length > 0) {
      this.opener(url);
    }
  }

  /** Reads the URL and the page title from the run's web actions. */
  capture(outcomes: ActionOutcome[], browser: BrowserController): void {
    for (const outcome of outcomes) {
      if (!outcome.executed || !outcome.observation.success) {
        continue;
      }
      const kind: string = outcome.action.kind;
      if (kind === 'web.navigate' && outcome.action.url.length > 0) {
        this.lastUrl = outcome.action.url;
      } else if (kind.startsWith('web.')) {
        const current: string = browser.currentUrl();
        if (current.startsWith('https://')) {
          this.lastUrl = current;
        }
      }
      if (kind === 'web.read') {
        const text: string = outcome.observation.summary;
        for (const line of text.split('\n')) {
          if (line.startsWith('TITLE: ')) {
            this.lastTitle = line.substring(7).trim();
            break;
          }
        }
      }
    }
  }
}
