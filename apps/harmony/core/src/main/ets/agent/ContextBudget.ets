import { ModelMessage } from '../model/ModelClient';

/**
 * Keeps the prompt bounded during long runs.
 *
 * The system message and the most recent turns are kept intact. Older
 * observation messages are shortened to a note; they are context, not
 * instructions, so losing detail is safe. Nothing is ever silently dropped from
 * the last few turns.
 */
export class ContextBudget {
  private maxChars: number;
  private keepRecent: number;
  private oldChars: number;

  constructor(maxChars: number = 24000, keepRecent: number = 6, oldChars: number = 400) {
    this.maxChars = maxChars;
    this.keepRecent = keepRecent;
    this.oldChars = oldChars;
  }

  size(messages: ModelMessage[]): number {
    let total: number = 0;
    for (const message of messages) {
      total += message.content.length;
    }
    return total;
  }

  trim(messages: ModelMessage[]): ModelMessage[] {
    if (this.size(messages) <= this.maxChars) {
      return messages;
    }
    if (messages.length <= this.keepRecent + 1) {
      return this.hardTrim(messages);
    }

    const trimmed: ModelMessage[] = [];
    const split: number = messages.length - this.keepRecent;
    for (let index = 0; index < messages.length; index++) {
      const message: ModelMessage = messages[index];
      if (index === 0 || index >= split) {
        trimmed.push(message);
        continue;
      }
      if (message.content.length > this.oldChars) {
        trimmed.push(
          new ModelMessage(
            message.role,
            `${message.content.substring(0, this.oldChars)}\n… [earlier context shortened]`
          )
        );
      } else {
        trimmed.push(message);
      }
    }
    return trimmed;
  }

  /** Last resort when even the recent turns are too large. */
  private hardTrim(messages: ModelMessage[]): ModelMessage[] {
    const trimmed: ModelMessage[] = [];
    const perMessage: number = Math.floor(this.maxChars / Math.max(messages.length, 1));
    for (const message of messages) {
      if (message.content.length <= perMessage) {
        trimmed.push(message);
      } else {
        trimmed.push(new ModelMessage(message.role, message.content.substring(0, perMessage)));
      }
    }
    return trimmed;
  }
}
