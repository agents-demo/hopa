import {
  Action,
  ActionExecutor,
  ApprovalPolicy,
  RunStore
} from '@hopa/core';
import {
  AgentRuntime,
  BridgeClient,
  BridgeScreenSource,
  ChatSync,
  MemoryStore,
  RemoteUiCapability,
  RemoteUiGates,
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
 * This machine has no accessibility service and no local way to drive another
 * app, so the PC bridge is its only pair of hands: it observes the screen,
 * taps, types and launches through `pc-agent bridge`. With the bridge off the
 * runtime answers questions and refuses actions instead of pretending.
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

/**
 * On a desktop the bridge is not a fallback, it is the path. HOPA's own window
 * can appear in a screenshot, so the loop is told about it through the
 * approval gate rather than an accessibility flag.
 */
class LaptopGates implements RemoteUiGates {
  selfInFront(): boolean {
    return false;
  }

  preferBridge(): boolean {
    return true;
  }
}

export class LaptopAgent {
  readonly runtime: AgentRuntime;
  readonly memory: MemoryStore = new MemoryStore();
  readonly skills: SkillStore = new SkillStore();
  readonly approvals: LaptopApprovals = new LaptopApprovals();
  readonly bridge: BridgeClient = new BridgeClient();
  readonly chatSync: ChatSync = new ChatSync();
  private executor: ActionExecutor;

  /** Only for the approval demo; not part of the runtime path. */
  executorForDemo(): ActionExecutor {
    return this.executor;
  }

  constructor() {
    this.bridge.setRole('2in1');
    const gates: LaptopGates = new LaptopGates();
    const executor = new ActionExecutor(
      new ApprovalPolicy(),
      this.approvals,
      new RunStore()
    );
    executor.registerCapability(new RemoteUiCapability(this.bridge, gates));
    this.executor = executor;
    this.runtime = new AgentRuntime(
      executor,
      this.memory,
      this.skills,
      new NoBrowser(),
      this.bridge,
      new NoAccessibility(),
      new NoBackground(),
      new NoPageLinks(),
      new BridgeScreenSource(this.bridge, gates)
    );
  }

  /** Points the bridge capability at a running `pc-agent bridge`. */
  configureBridge(url: string, token: string): void {
    this.bridge.configure(url, token);
    this.chatSync.configure(url, token, '2in1');
  }

  isBridgeConfigured(): boolean {
    return this.bridge.isConfigured();
  }

  async testBridge(): Promise<boolean> {
    return this.bridge.health();
  }

  bridgeFailure(): string {
    return this.bridge.lastFailure();
  }
}

/**
 * Verification hook: push a sensitive action through the real gate.
 *
 * The approval card, the pause and the answer path are exactly the ones a run
 * would use; whether the action then lands depends on the bridge.
 */
export async function demoApproval(agent: LaptopAgent): Promise<string> {
  const action = new Action('system.sendMessage');
  action.target = 'Alex';
  action.text = 'hello';
  const outcome = await agent.executorForDemo().execute(action);
  return outcome.observation.summary;
}
