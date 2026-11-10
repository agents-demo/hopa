import {
  Action,
  ActionExecutor,
  ApprovalGateway,
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

/**
 * The laptop's binding of the shared runtime.
 *
 * It supplies honest "no" implementations for what this machine cannot do:
 * no screen capture, no app control, no accessibility tree, no page links.
 * The runtime therefore answers questions and refuses actions, instead of
 * pretending it can drive another window.
 */

class DenyAllGateway implements ApprovalGateway {
  async requestApproval(action: Action, screen?: Screen): Promise<boolean> {
    return false;
  }
}

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

  constructor() {
    const executor = new ActionExecutor(
      new ApprovalPolicy(),
      new DenyAllGateway(),
      new RunStore()
    );
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
