import { describe, expect, it } from '@ohos/hypium';
import { ModelMessage } from '../main/ets/model/ModelClient';
import { ContextBudget } from '../main/ets/agent/ContextBudget';

function messages(count: number, size: number): ModelMessage[] {
  const list: ModelMessage[] = [new ModelMessage('system', 'system')];
  let payload: string = '';
  for (let index = 0; index < size; index++) {
    payload += 'x';
  }
  for (let index = 0; index < count; index++) {
    list.push(new ModelMessage(index % 2 === 0 ? 'user' : 'assistant', payload));
  }
  return list;
}

export default function contextBudgetTest(): void {
  describe('ContextBudget', () => {
    it('leaves_a_small_prompt_unchanged', 0, () => {
      const budget = new ContextBudget(1000, 4, 100);
      const input = messages(2, 10);
      expect(budget.trim(input) === input).assertTrue();
    });

    it('keeps_the_system_message', 0, () => {
      const budget = new ContextBudget(200, 2, 10);
      const trimmed = budget.trim(messages(10, 100));
      expect(trimmed[0].role).assertEqual('system');
      expect(trimmed[0].content).assertEqual('system');
    });

    it('shortens_old_turns_only', 0, () => {
      const budget = new ContextBudget(200, 2, 10);
      const trimmed = budget.trim(messages(6, 100));
      expect(trimmed[1].content.includes('earlier context shortened')).assertTrue();
      const last = trimmed[trimmed.length - 1];
      expect(last.content.length).assertEqual(100);
    });

    it('hard_trims_when_even_recent_turns_are_large', 0, () => {
      const budget = new ContextBudget(60, 10, 5);
      const trimmed = budget.trim(messages(2, 100));
      for (const message of trimmed) {
        expect(message.content.length <= 60).assertTrue();
      }
    });

    it('size_counts_all_messages', 0, () => {
      const budget = new ContextBudget();
      expect(budget.size(messages(3, 10))).assertEqual('system'.length + 30);
    });
  });
}
