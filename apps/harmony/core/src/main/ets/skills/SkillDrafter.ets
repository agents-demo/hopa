/**
 * Turns a successful run into a skill draft.
 *
 * The draft is text, not a recorded script: refs and coordinates are stale by
 * the next run, so replaying them would be unsafe. The user confirms the draft
 * before it is saved.
 */
export class SkillDraft {
  name: string = '';
  trigger: string = '';
  guidance: string = '';
}

export class SkillDrafter {
  static readonly MAX_NAME: number = 80;
  static readonly MAX_TRIGGER: number = 120;
  static readonly MAX_GUIDANCE: number = 1500;

  static draft(goal: string, transcript: string): SkillDraft | undefined {
    const cleanGoal: string = goal.trim();
    const cleanTranscript: string = transcript.trim();
    if (cleanGoal.length === 0 || cleanTranscript.length === 0) {
      return undefined;
    }
    const draft = new SkillDraft();
    draft.name = cleanGoal.length > SkillDrafter.MAX_NAME
      ? cleanGoal.substring(0, SkillDrafter.MAX_NAME)
      : cleanGoal;
    draft.trigger = cleanGoal.length > SkillDrafter.MAX_TRIGGER
      ? cleanGoal.substring(0, SkillDrafter.MAX_TRIGGER)
      : cleanGoal;
    const steps: string = cleanTranscript.length > SkillDrafter.MAX_GUIDANCE
      ? cleanTranscript.substring(0, SkillDrafter.MAX_GUIDANCE)
      : cleanTranscript;
    const guidance: string = `When asked: ${cleanGoal}\nPrevious successful steps:\n${steps}`;
    draft.guidance = guidance.length > SkillDrafter.MAX_GUIDANCE
      ? guidance.substring(0, SkillDrafter.MAX_GUIDANCE)
      : guidance;
    return draft;
  }
}
