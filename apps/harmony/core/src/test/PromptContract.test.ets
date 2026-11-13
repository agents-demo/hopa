import { describe, expect, it } from '@ohos/hypium';
import { PromptBuilder } from '../main/ets/agent/PromptBuilder';
import { PROMPT_RULES } from '../main/ets/agent/PromptRules';

export default function promptContractTest(): void {
  describe('PromptContract', () => {
    it('carries_every_shared_rule', 0, () => {
      const prompt: string = PromptBuilder.systemPrompt('', '', '', true);
      for (const rule of PROMPT_RULES) {
        for (const phrase of rule.phrases) {
          if (prompt.indexOf(phrase) < 0) {
            throw new Error(`missing prompt rule ${rule.id}: ${phrase}`);
          }
        }
      }
      expect(PROMPT_RULES.length > 0).assertTrue();
    });
  });
}
