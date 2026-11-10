import {
  Action,
  ActionExecutor,
  ApprovalPolicy,
  RunStore,
  Screen,
  ScreenSource
} from '@hopa/core';
import {
  AgentRuntime,
  BridgeClient,
  MemoryStore,
  RuntimeBackground,
  RuntimeBrowser,
  RuntimeAccessibility,
  RuntimePageLinks,
  SkillStore
} from '@hopa/app';
import { LaptopApprovals } from './LaptopApprovals';

/**
 * The laptop's binding of the shared runtime.
 *
 * It supplies honest "no" implementations for what this machine cannot do:
 * no screen capture, no app control, no accessibility tree, no page links.
 * The runtime therefore answers questions and refuses actions, instead of
 * pretending it can drive another window.
 */

class NoBrowser implements RuntimeBrowser {
  isReady(): boolean {
    return false;
  }

  currentUrl(): string {
    return '';
  }

  currentTitle(): string {
    return '';
  }

  async pageText(): Promise<string> {
    return '';
  }
}

class NoBackground implements RuntimeBackground {
  async begin(): Promise<void> {}

  async end(): Promise<void> {}

  async returnToForeground(): Promise<boolean> {
    return false;
  }
}

class NoAccessibility implements RuntimeAccessibility {
  isAvailable(): boolean {
    return false;
  }
}

class NoPageLinks implements RuntimePageLinks {
  capture(outcomes: Object[], browser: RuntimeBrowser): void {}

  clear(): void {}
}

class EmptyScreen implements ScreenSource {
  async capture(): Promise<Screen> {
    return new Screen('');
  }
}

export class LaptopAgent {
  readonly runtime: AgentRuntime;
  readonly memory: MemoryStore = new MemoryStore();
  readonly skills: SkillStore = new SkillStore();
  readonly approvals: LaptopApprovals = new LaptopApprovals();
  private executor: ActionExecutor;

  /** Only for the approval demo; not part of the runtime path. */
  executorForDemo(): ActionExecutor {
    return this.executor;
  }

  constructor() {
    const executor = new ActionExecutor(
      new ApprovalPolicy(),
      this.approvals,
      new RunStore()
    );
    this.executor = executor;
    this.runtime = new AgentRuntime(
      executor,
      this.memory,
      this.skills,
      new NoBrowser(),
      new BridgeClient(),
      new NoAccessibility(),
      new NoBackground(),
      new NoPageLinks(),
      new EmptyScreen()
    );
  }
}

/**
 * Verification hook: push a sensitive action through the real gate.
 *
 * Nothing executes on the laptop (there is no capability), but the approval
 * card, the pause and the answer path are exactly the ones a run would use.
 */
export async function demoApproval(agent: LaptopAgent): Promise<string> {
  const action = new Action('system.sendMessage');
  action.target = 'Alex';
  action.text = 'hello';
  const outcome = await agent.executorForDemo().execute(action);
  return outcome.observation.summary;
}
