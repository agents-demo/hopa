import { describe, expect, it } from '@ohos/hypium';
import { BatchItemResult, BatchRunner } from '../main/ets/runs/BatchRunner';

export default function batchRunnerTest(): void {
  describe('BatchRunner', () => {
    it('runs_goals_in_order', 0, async (done: Function) => {
      const seen: string[] = [];
      const runner = new BatchRunner();
      const results: BatchItemResult[] = await runner.run(
        ['one', 'two', 'three'],
        async (goal: string): Promise<string> => {
          seen.push(goal);
          return `did ${goal}`;
        }
      );
      expect(seen.length).assertEqual(3);
      expect(results.length).assertEqual(3);
      expect(results[1].goal).assertEqual('two');
      expect(results[2].output).assertEqual('did three');
      done();
    });

    it('stops_between_goals_when_cancelled', 0, async (done: Function) => {
      const runner = new BatchRunner();
      const results: BatchItemResult[] = await runner.run(
        ['one', 'two', 'three'],
        async (goal: string): Promise<string> => {
          if (goal === 'one') {
            runner.cancel();
          }
          return goal;
        }
      );
      expect(results.length).assertEqual(1);
      expect(runner.wasCancelled()).assertTrue();
      done();
    });

    it('records_an_error_and_continues', 0, async (done: Function) => {
      const runner = new BatchRunner();
      const results: BatchItemResult[] = await runner.run(
        ['bad', 'good'],
        async (goal: string): Promise<string> => {
          if (goal === 'bad') {
            throw new Error('boom');
          }
          return 'ok';
        }
      );
      expect(results.length).assertEqual(2);
      expect(results[0].output.includes('boom')).assertTrue();
      expect(results[1].output).assertEqual('ok');
      done();
    });

    it('measures_duration', 0, async (done: Function) => {
      const runner = new BatchRunner();
      const results: BatchItemResult[] = await runner.run(
        ['one'],
        async (): Promise<string> => 'x'
      );
      expect(results[0].durationMs >= 0).assertTrue();
      done();
    });
  });
}
