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
