/**
 * Personal skills: user-authored instructions that apply when a goal matches.
 *
 * A skill is text, not a recorded script. Replaying coordinates would be
 * brittle and unsafe; injecting guidance lets the model adapt to the current
 * screen while still following a known-good procedure.
 */
export class Skill {
  id: string = '';
  name: string = '';
  trigger: string = '';
  guidance: string = '';
  createdAt: number = 0;
  uses: number = 0;
  successes: number = 0;
}

export class SkillBook {
  private items: Skill[] = [];

  all(): Skill[] {
    return this.items;
  }

  add(name: string, trigger: string, guidance: string): Skill | undefined {
    const cleanName: string = name.trim();
    const cleanGuidance: string = guidance.trim();
    if (cleanName.length === 0 || cleanGuidance.length === 0) {
      return undefined;
    }
    const skill = new Skill();
    skill.id = `s-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
    skill.name = cleanName.length > 80 ? cleanName.substring(0, 80) : cleanName;
    const cleanTrigger: string = trigger.trim().length > 0 ? trigger.trim() : cleanName;
    skill.trigger = cleanTrigger.length > 120 ? cleanTrigger.substring(0, 120) : cleanTrigger;
    skill.guidance = cleanGuidance.length > 2000 ? cleanGuidance.substring(0, 2000) : cleanGuidance;
    skill.createdAt = Date.now();
    this.items.unshift(skill);
    return skill;
  }

  remove(id: string): boolean {
    const before: number = this.items.length;
    this.items = this.items.filter((item: Skill) => item.id !== id);
    return this.items.length !== before;
  }

  clear(): void {
    this.items = [];
  }

  /** Records that a matched skill was used and whether the run succeeded. */
  recordOutcome(id: string, success: boolean): void {
    for (const skill of this.items) {
      if (skill.id === id) {
        skill.uses += 1;
        if (success) {
          skill.successes += 1;
        }
        return;
      }
    }
  }

  /** Longest trigger that occurs in the goal wins; no trigger means no match. */
  match(goal: string): Skill | undefined {
    const haystack: string = goal.toLowerCase();
    let best: Skill | undefined = undefined;
    for (const skill of this.items) {
      const trigger: string = skill.trigger.toLowerCase().trim();
      if (trigger.length === 0 || !haystack.includes(trigger)) {
        continue;
      }
      if (best === undefined || trigger.length > best.trigger.length) {
        best = skill;
      }
    }
    return best;
  }

  /** Prompt block for the best matching skill, or an empty string. */
  toPrompt(goal: string): string {
    const skill: Skill | undefined = this.match(goal);
    if (skill === undefined) {
      return '';
    }
    return `A saved skill may apply.\nName: ${skill.name}\nWhen: ${skill.trigger}\n` +
      `Procedure:\n${skill.guidance}\n` +
      'Follow it when the current screen allows, and stop for approval as usual.';
  }
}
