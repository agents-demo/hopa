/**
 * Deterministic lexical router.
 *
 * This is the ArkTS port of
 * `services/brain/src/main/kotlin/hopa/brain/routing/Router.kt`. It does not
 * execute anything: it names the most likely app or site for a goal so the
 * model starts in the right place instead of guessing.
 *
 * Rules: match the display name, the catalogue name, aliases, bundles and site
 * domains as whole words; the longest matched term wins; a target that can
 * actually be opened (a verified bundle or a domain) wins a tie.
 */

export class RouteTarget {
  name: string = '';
  display: string = '';
  kind: string = '';        // 'app' or 'site'
  bundle: string = '';      // apps only
  domains: string[] = [];   // sites only
  aliases: string[] = [];
  purpose: string = '';
  actions: string[] = [];
}

export class RouteMatch {
  target: RouteTarget | undefined = undefined;
  score: number = 0;
  term: string = '';
}

export class AppRouter {
  private static readonly GENERIC: string[] = [
    'app', 'apps', 'web', 'www', 'site', 'website', 'browser', 'phone',
    'open', 'use', '应用', '网站', '网页', '浏览器', '打开', '使用'
  ];

  /** The best target for a goal, or an empty match. */
  static route(goal: string, targets: RouteTarget[]): RouteMatch {
    const text: string = goal.trim().toLowerCase();
    let best: RouteMatch = new RouteMatch();
    if (text.length === 0) {
      return best;
    }
    for (const target of targets) {
      const scored: RouteMatch = AppRouter.score(target, text);
      if (scored.score <= 0) {
        continue;
      }
      const current: RouteTarget | undefined = best.target;
      if (
        current === undefined ||
        scored.score > best.score ||
        (scored.score === best.score && AppRouter.canOpen(target) && !AppRouter.canOpen(current))
      ) {
        best = scored;
      }
    }
    return best;
  }

  /** One prompt line for the model, or '' when nothing matched. */
  static hint(match: RouteMatch): string {
    const target: RouteTarget | undefined = match.target;
    if (target === undefined) {
      return '';
    }
    if (target.kind === 'site') {
      const domain: string = target.domains.length > 0 ? target.domains[0] : '';
      if (domain.length === 0) {
        return '';
      }
      return `ROUTER SUGGESTION: this is a ${target.display} task. ` +
        `Open https://${domain} with {"kind":"web.navigate","url":"https://${domain}"} ` +
        'when the network toggle is on, then read the page and use its element refs.';
    }
    if (target.bundle.length === 0) {
      return `ROUTER SUGGESTION: this looks like a ${target.display} task, ` +
        'but no HarmonyOS bundle is verified for it. Do not guess a bundle; ' +
        'say what is missing and offer the web channel if one exists.';
    }
    return `ROUTER SUGGESTION: this is a ${target.display} task. ` +
      `Start with {"kind":"ui.launch","app":"${target.bundle}"}, ` +
      'then act on the ELEMENTS of the new screen.';
  }

  private static canOpen(target: RouteTarget): boolean {
    return target.bundle.length > 0 || target.domains.length > 0;
  }

  private static score(target: RouteTarget, text: string): RouteMatch {
    const match: RouteMatch = new RouteMatch();
    let best: number = -1;
    let term: string = '';
    const terms: string[] = [target.display, target.name].concat(target.aliases);
    for (const raw of terms) {
      const value: string = raw.trim().toLowerCase();
      if (value.length < 2 || AppRouter.GENERIC.indexOf(value) >= 0) {
        continue;
      }
      if (AppRouter.allDigits(value) && value.length < 3) {
        continue;
      }
      if (AppRouter.containsTerm(text, value) && value.length > best) {
        best = value.length;
        term = value;
      }
    }
    for (const domain of target.domains) {
      const value: string = AppRouter.normaliseHost(domain);
      if (value.length >= 3 && text.includes(value) && value.length > best) {
        best = value.length;
        term = value;
      }
    }
    if (target.bundle.length >= 3 && text.includes(target.bundle.toLowerCase()) &&
      target.bundle.length > best) {
      best = target.bundle.length;
      term = target.bundle.toLowerCase();
    }
    if (best < 0) {
      return match;
    }
    match.target = target;
    match.score = best;
    match.term = term;
    return match;
  }

  private static containsTerm(text: string, term: string): boolean {
    let from: number = 0;
    while (true) {
      const index: number = text.indexOf(term, from);
      if (index < 0) {
        return false;
      }
      const before: string = index > 0 ? text.charAt(index - 1) : '';
      const after: string = index + term.length < text.length ? text.charAt(index + term.length) : '';
      const leftOk: boolean = !AppRouter.isAsciiAlnum(term.charAt(0)) ||
        before.length === 0 || !AppRouter.isAsciiAlnum(before);
      const rightOk: boolean = !AppRouter.isAsciiAlnum(term.charAt(term.length - 1)) ||
        after.length === 0 || !AppRouter.isAsciiAlnum(after);
      if (leftOk && rightOk) {
        return true;
      }
      from = index + 1;
    }
  }

  private static isAsciiAlnum(value: string): boolean {
    if (value.length === 0) {
      return false;
    }
    const code: number = value.charCodeAt(0);
    return (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
  }

  private static allDigits(value: string): boolean {
    for (let i = 0; i < value.length; i++) {
      const code: number = value.charCodeAt(i);
      if (code < 48 || code > 57) {
        return false;
      }
    }
    return value.length > 0;
  }

  private static normaliseHost(value: string): string {
    let host: string = value.trim().toLowerCase();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }
    return host;
  }
}
