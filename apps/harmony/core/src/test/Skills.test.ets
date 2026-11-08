import { describe, expect, it } from '@ohos/hypium';
import { Skill } from '../main/ets/skills/Skill';
import { SkillBook } from '../main/ets/skills/SkillBook';

export default function skillsTest(): void {
  describe('SkillBook', () => {
    it('adds_a_skill', 0, () => {
      const book = new SkillBook();
      const skill: Skill | undefined = book.add('Book a table', 'book a table', 'Open the app, pick a time, confirm.');
      expect(skill !== undefined).assertTrue();
      expect(book.all().length).assertEqual(1);
    });

    it('rejects_empty_skills', 0, () => {
      const book = new SkillBook();
      expect(book.add('', 'x', 'y') === undefined).assertTrue();
      expect(book.add('x', 'x', '') === undefined).assertTrue();
    });

    it('matches_a_trigger_inside_the_goal', 0, () => {
      const book = new SkillBook();
      book.add('Book a table', 'book a table', 'steps');
      const match: Skill | undefined = book.match('Please BOOK A TABLE for two tonight');
      expect(match !== undefined).assertTrue();
      expect(match?.name).assertEqual('Book a table');
    });

    it('does_not_match_unrelated_goals', 0, () => {
      const book = new SkillBook();
      book.add('Book a table', 'book a table', 'steps');
      expect(book.match('What is the weather?') === undefined).assertTrue();
      expect(book.toPrompt('What is the weather?')).assertEqual('');
    });

    it('longest_trigger_wins', 0, () => {
      const book = new SkillBook();
      book.add('Short', 'table', 'short steps');
      book.add('Long', 'book a table', 'long steps');
      expect(book.match('book a table')?.name).assertEqual('Long');
    });

    it('prompt_contains_guidance', 0, () => {
      const book = new SkillBook();
      book.add('Book a table', 'book a table', 'Pick 19:00 and confirm.');
      const prompt: string = book.toPrompt('book a table');
      expect(prompt.includes('Pick 19:00 and confirm.')).assertTrue();
      expect(prompt.includes('stop for approval')).assertTrue();
    });

    it('removes_a_skill', 0, () => {
      const book = new SkillBook();
      const skill: Skill | undefined = book.add('X', 'x', 'steps');
      expect(skill !== undefined).assertTrue();
      expect(book.remove(skill?.id ?? '')).assertTrue();
      expect(book.all().length).assertEqual(0);
    });

    it('records_uses_and_successes', 0, () => {
      const book = new SkillBook();
      const skill: Skill | undefined = book.add('X', 'x', 'steps');
      const id: string = skill?.id ?? '';
      book.recordOutcome(id, true);
      book.recordOutcome(id, false);
      expect(book.all()[0].uses).assertEqual(2);
      expect(book.all()[0].successes).assertEqual(1);
    });
  });
}
