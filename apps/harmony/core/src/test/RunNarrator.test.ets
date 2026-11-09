import { describe, expect, it } from '@ohos/hypium';
import { Action, ActionOutcome, Observation } from '../main/ets/Types';
import { RunNarrator } from '../main/ets/agent/RunNarrator';

function catalogue(): Map<string, string> {
  const names = new Map<string, string>();
  names.set('com.huawei.hmos.settings', 'Settings');
  return names;
}

function outcome(action: Action, observation: Observation, executed: boolean = true): ActionOutcome {
  const result = new ActionOutcome(action, observation);
  result.executed = executed;
  result.approved = true;
  return result;
}

export default function runNarratorTest(): void {
  describe('RunNarrator', () => {
    it('summarizes_a_launch_and_a_tap', 0, () => {
      const launch = new Action('ui.launch');
      launch.app = 'com.huawei.hmos.settings';
      const tap = new Action('ui.tap');
      tap.target = 'e8';
      const text: string = RunNarrator.summarize(
        [outcome(launch, Observation.ok('launched')), outcome(tap, Observation.ok('tapped'))],
        catalogue()
      );
      expect(text.includes('Opened Settings')).assertTrue();
      expect(text.includes('Tapped a control')).assertTrue();
      expect(text.includes('ui.launch')).assertFalse();
      expect(text.startsWith('Done')).assertFalse();
    });

    it('uses_the_display_name_when_the_launch_fails', 0, () => {
      const launch = new Action('ui.launch');
      launch.app = 'com.huawei.hmos.settings';
      const text: string = RunNarrator.summarize(
        [outcome(launch, Observation.fail('not installed on this device'))],
        catalogue()
      );
      expect(text.includes('Settings')).assertTrue();
      expect(text.includes('not installed on this device')).assertTrue();
    });

    it('explains_a_denied_step', 0, () => {
      const launch = new Action('ui.launch');
      launch.app = 'com.huawei.hmos.settings';
      const text: string = RunNarrator.summarize(
        [outcome(launch, Observation.fail('payment denied by user'), false)],
        catalogue()
      );
      expect(text.startsWith('I stopped')).assertTrue();
    });

    it('groups_repeated_taps', 0, () => {
      const outcomes: ActionOutcome[] = [];
      for (let index = 0; index < 5; index++) {
        const tap = new Action('ui.tap');
        tap.target = `e${index}`;
        outcomes.push(outcome(tap, Observation.ok('tapped')));
      }
      const text: string = RunNarrator.summarize(outcomes, catalogue());
      expect(text.includes('Tapped 5 controls.')).assertTrue();
      expect(text.includes('Done')).assertFalse();
    });

    it('shows_the_typed_text', 0, () => {
      const type = new Action('ui.type');
      type.text = 'Hello World';
      const text: string = RunNarrator.summarize(
        [outcome(type, Observation.ok('typed'))],
        catalogue()
      );
      expect(text.includes('Hello World')).assertTrue();
    });

    it('falls_back_to_the_bundle', 0, () => {
      const launch = new Action('ui.launch');
      launch.app = 'com.example.demo';
      const text: string = RunNarrator.summarize(
        [outcome(launch, Observation.ok('launched'))],
        catalogue()
      );
      expect(text.includes('com.example.demo')).assertTrue();
    });
  });
}
