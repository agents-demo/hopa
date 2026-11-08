import { describe, expect, it } from '@ohos/hypium';
import { SkillDraft, SkillDrafter } from '../main/ets/skills/SkillDrafter';

export default function skillDrafterTest(): void {
  describe('SkillDrafter', () => {
    it('drafts_from_a_goal_and_transcript', 0, () => {
      const draft: SkillDraft | undefined = SkillDrafter.draft(
        'Book a table',
        'ui.tap -> ok: opened the app'
      );
      expect(draft !== undefined).assertTrue();
      expect(draft?.name).assertEqual('Book a table');
      expect(draft?.trigger).assertEqual('Book a table');
      expect(draft?.guidance.includes('opened the app')).assertTrue();
    });

    it('rejects_empty_input', 0, () => {
      expect(SkillDrafter.draft('', 'steps') === undefined).assertTrue();
      expect(SkillDrafter.draft('goal', '   ') === undefined).assertTrue();
    });

    it('caps_long_fields', 0, () => {
      let longGoal: string = '';
      for (let index = 0; index < 200; index++) {
        longGoal += 'g';
      }
      let longSteps: string = '';
      for (let index = 0; index < 2000; index++) {
        longSteps += 's';
      }
      const draft: SkillDraft | undefined = SkillDrafter.draft(longGoal, longSteps);
      const value: SkillDraft = draft as SkillDraft;
      expect(value.name.length).assertEqual(SkillDrafter.MAX_NAME);
      expect(value.trigger.length).assertEqual(SkillDrafter.MAX_TRIGGER);
      expect(value.guidance.length <= SkillDrafter.MAX_GUIDANCE).assertTrue();
    });
  });
}
