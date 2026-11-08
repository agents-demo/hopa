import { Context } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Skill, SkillBook, SkillDraft, SkillDrafter } from '@hopa/core';

/** Persists user-authored skills. */
export class SkillStore {
  private static readonly STORE: string = 'hopa_settings';
  private static readonly KEY: string = 'skills_v1';

  private book: SkillBook = new SkillBook();

  all(): Skill[] {
    return this.book.all();
  }

  add(name: string, trigger: string, guidance: string): Skill | undefined {
    return this.book.add(name, trigger, guidance);
  }

  /** Draft a skill from a successful run and save it. */
  draftFrom(goal: string, transcript: string): Skill | undefined {
    const draft: SkillDraft | undefined = SkillDrafter.draft(goal, transcript);
    if (draft === undefined) {
      return undefined;
    }
    return this.add(draft.name, draft.trigger, draft.guidance);
  }

  remove(id: string): boolean {
    return this.book.remove(id);
  }

  toPrompt(goal: string): string {
    return this.book.toPrompt(goal);
  }

  match(goal: string): Skill | undefined {
    return this.book.match(goal);
  }

  recordOutcome(id: string, success: boolean): void {
    this.book.recordOutcome(id, success);
  }

  async load(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, SkillStore.STORE);
    const raw = await store.get(SkillStore.KEY, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as Skill[];
      this.book.clear();
      for (const item of parsed) {
        if (item.name.length > 0 && item.guidance.length > 0) {
          const added: Skill | undefined = this.book.add(item.name, item.trigger, item.guidance);
          if (added !== undefined) {
            added.id = item.id;
            added.createdAt = item.createdAt;
            added.uses = item.uses;
          }
        }
      }
    } catch (error) {
      // Unreadable store: keep an empty book rather than crashing.
    }
  }

  async save(context: Context): Promise<void> {
    const store = await preferences.getPreferences(context, SkillStore.STORE);
    await store.put(SkillStore.KEY, JSON.stringify(this.book.all()));
    await store.flush();
  }
}
