/**
 * Hand-off from an intent (share sheet or `hopa://ask?...`) into the UI.
 *
 * The ability runs before any page exists, so it parks the text here and the
 * shell takes it once it is alive.
 */
export class IntentInbox {
  private static goal: string = '';

  static put(goal: string): void {
    const text: string = goal.trim();
    if (text.length > 0) {
      IntentInbox.goal = text;
    }
  }

  static peek(): string {
    return IntentInbox.goal;
  }

  static take(): string {
    const text: string = IntentInbox.goal;
    IntentInbox.goal = '';
    return text;
  }
}
