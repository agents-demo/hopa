import { describe, expect, it } from '@ohos/hypium';
import { AppRouter, RouteMatch, RouteTarget } from '../main/ets/router/AppRouter';

function app(name: string, display: string, bundle: string, aliases: string[]): RouteTarget {
  const target = new RouteTarget();
  target.name = name;
  target.display = display;
  target.kind = 'app';
  target.bundle = bundle;
  target.aliases = aliases;
  return target;
}

function site(name: string, display: string, domain: string, aliases: string[]): RouteTarget {
  const target = new RouteTarget();
  target.name = name;
  target.display = display;
  target.kind = 'site';
  target.domains = [domain];
  target.aliases = aliases;
  return target;
}

function catalogue(): RouteTarget[] {
  return [
    app('clock', 'Clock', 'com.huawei.hmos.clock', ['clock', 'alarm', '闹钟']),
    app('settings', 'Settings', 'com.huawei.hmos.settings', ['settings', '设置']),
    app('wechat', 'WeChat', '', ['wechat', 'weixin']),
    app('mail', 'Mail', 'com.example.mail', ['mail', 'email']),
    app('gmail', 'Gmail', 'com.example.gmail', ['gmail']),
    site('booking', 'Booking', 'booking.com', ['booking', 'hotel'])
  ];
}

export default function appRouterTest(): void {
  describe('AppRouter', () => {
    it('matches_an_alias', 0, () => {
      const match: RouteMatch = AppRouter.route('check my alarm tomorrow', catalogue());
      expect(match.target !== undefined).assertTrue();
      if (match.target !== undefined) {
        expect(match.target.display).assertEqual('Clock');
      }
      expect(match.score).assertEqual(5);
    });

    it('prefers_the_longest_term', 0, () => {
      const match: RouteMatch = AppRouter.route('open gmail', catalogue());
      expect(match.target !== undefined).assertTrue();
      if (match.target !== undefined) {
        expect(match.target.display).assertEqual('Gmail');
      }
    });

    it('ignores_generic_words', 0, () => {
      const match: RouteMatch = AppRouter.route('open the app', catalogue());
      expect(match.target === undefined).assertTrue();
      expect(AppRouter.hint(match)).assertEqual('');
    });

    it('matches_a_site_domain', 0, () => {
      const match: RouteMatch = AppRouter.route('book a hotel on booking.com', catalogue());
      expect(match.target !== undefined).assertTrue();
      const hint: string = AppRouter.hint(match);
      expect(hint.includes('web.navigate')).assertTrue();
      expect(hint.includes('https://booking.com')).assertTrue();
    });

    it('warns_when_the_bundle_is_not_verified', 0, () => {
      const match: RouteMatch = AppRouter.route('message alice on wechat', catalogue());
      expect(match.target !== undefined).assertTrue();
      const hint: string = AppRouter.hint(match);
      expect(hint.includes('no HarmonyOS bundle')).assertTrue();
    });

    it('matches_the_bundle_name', 0, () => {
      const match: RouteMatch = AppRouter.route('launch com.huawei.hmos.settings', catalogue());
      expect(match.target !== undefined).assertTrue();
      if (match.target !== undefined) {
        expect(match.target.display).assertEqual('Settings');
      }
    });

    it('does_not_match_inside_a_word', 0, () => {
      const match: RouteMatch = AppRouter.route('fix the offset', catalogue());
      expect(match.target === undefined).assertTrue();
    });

    it('keeps_the_longest_of_two_aliases', 0, () => {
      const match: RouteMatch = AppRouter.route('send email', catalogue());
      expect(match.target !== undefined).assertTrue();
      if (match.target !== undefined) {
        expect(match.target.display).assertEqual('Mail');
      }
    });
  });
}
