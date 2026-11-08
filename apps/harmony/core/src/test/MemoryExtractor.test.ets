import { describe, expect, it } from '@ohos/hypium';
import { MemoryExtractor } from '../main/ets/memory/MemoryExtractor';

export default function memoryExtractorTest(): void {
  describe('MemoryExtractor', () => {
    it('extracts_an_explicit_fact', 0, () => {
      expect(MemoryExtractor.extract('Remember that I prefer aisle seats'))
        .assertEqual('I prefer aisle seats');
    });

    it('handles_polite_prefix', 0, () => {
      expect(MemoryExtractor.extract('Please remember my gate is B12'))
        .assertEqual('my gate is B12');
    });

    it('ignores_normal_messages', 0, () => {
      expect(MemoryExtractor.extract('What is the weather?') === undefined).assertTrue();
    });

    it('ignores_empty_remember', 0, () => {
      expect(MemoryExtractor.extract('remember   ') === undefined).assertTrue();
    });

    it('extracts_chinese', 0, () => {
      expect(MemoryExtractor.extract('请记住我喜欢靠窗座位'))
        .assertEqual('我喜欢靠窗座位');
    });
  });
}
