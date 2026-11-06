/**
 * Runs several goals one after another through the same agent loop.
 *
 * There is no parallelism: one device, one screen. Cancellation stops between
 * goals and is forwarded to the current run by the caller.
 */
export class BatchItemResult {
  goal: string = '';
  output: string = '';
  durationMs: number = 0;
}

export class BatchRunner {
  private cancelled: boolean = false;

  cancel(): void {
    this.cancelled = true;
  }

  wasCancelled(): boolean {
    return this.cancelled;
  }

  async run(
    goals: string[],
    runOne: (goal: string) => Promise<string>
  ): Promise<BatchItemResult[]> {
    const results: BatchItemResult[] = [];
    this.cancelled = false;
    for (const goal of goals) {
      if (this.cancelled) {
        break;
      }
      const startedAt: number = Date.now();
      const result = new BatchItemResult();
      result.goal = goal;
      try {
        result.output = await runOne(goal);
      } catch (error) {
        result.output = `error: ${error}`;
      }
      result.durationMs = Date.now() - startedAt;
      results.push(result);
    }
    return results;
  }
}
