import { AgentService } from './AgentService';

/**
 * Runs one goal and reports the latest plain step.
 *
 * Both Easy and Kid used to copy the same poll loop; the chat keeps its own
 * ticker because it also renders the transcript.
 */
export class TaskRunner {
  private poll: number = -1;

  /** Resolves with the final answer; `onStep` receives a plain line. */
  async run(goal: string, onStep: (line: string) => void): Promise<string> {
    this.clear();
    onStep('Getting ready');
    this.poll = setInterval(() => {
      const steps: string[] = AgentService.get().runtime.lastSteps();
      if (steps.length > 0) {
        const line: string = steps[steps.length - 1];
        onStep(line.length > 2 ? line.substring(2) : line);
      }
    }, 500);
    try {
      return await AgentService.get().run(goal);
    } finally {
      this.clear();
    }
  }

  cancel(): void {
    AgentService.get().cancel();
  }

  clear(): void {
    if (this.poll >= 0) {
      clearInterval(this.poll);
      this.poll = -1;
    }
  }
}
