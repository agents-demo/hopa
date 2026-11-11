import {
  Action,
  ActionCapability,
  ActionExecutor,
  ApprovalPolicy,
  Observation,
  RunStore
} from '@hopa/core';
import {
  AgentRuntime,
  BridgeClient,
  BridgeScreenSource,
  ChatSync,
  ScheduleService,
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
import { LaptopBrowser } from './LaptopBrowser';
import { LaptopLauncher } from './LaptopLauncher';
import { RunArchive } from '@hopa/app';

/**
 * The laptop's binding of the shared runtime.
 *
 * This machine has no accessibility service and no local way to drive another
 * app, so the PC bridge is its only pair of hands: it observes the screen,
 * taps, types and launches through `pc-agent bridge`. With the bridge off the
 * runtime answers questions and refuses actions instead of pretending.
 */

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

/**
 * Opening an app on this machine, with no bridge in the way.
 *
 * It sits before the bridge capability, so a local launch wins; the bridge
 * stays for taps, typing and screen reading.
 */
class LocalLaunchCapability implements ActionCapability {
  private launcher: LaptopLauncher;
  private isLocal: () => boolean;

  constructor(launcher: LaptopLauncher, isLocal: () => boolean) {
    this.launcher = launcher;
    this.isLocal = isLocal;
  }

  /**
   * Only this machine's launches. A run aimed at the phone must reach the
   * phone's launcher through the bridge, with the phone's bundle name - taking
   * it locally is how "open Douyin on the phone" failed on the laptop.
   */
  canHandle(kind: string): boolean {
    return kind === 'ui.launch' && this.isLocal();
  }

  async execute(action: Action): Promise<Observation> {
    const bundle: string = action.app.length > 0
      ? action.app
      : (action.target.startsWith('com.') ? action.target : '');
    if (bundle.length === 0) {
      return Observation.fail('ui.launch needs the app bundle in app');
    }
    const opened: boolean = await this.launcher.launch(bundle);
    return opened
      ? Observation.ok(`opened ${bundle} on this laptop`)
      : Observation.fail(`could not open ${bundle} here`);
  }
}

export class LaptopAgent {
  readonly runtime: AgentRuntime;
  readonly memory: MemoryStore = new MemoryStore();
  readonly skills: SkillStore = new SkillStore();
  readonly approvals: LaptopApprovals = new LaptopApprovals();
  readonly bridge: BridgeClient = new BridgeClient();
  readonly runs: RunStore = new RunStore();
  readonly browser: LaptopBrowser = new LaptopBrowser();
  readonly launcher: LaptopLauncher = new LaptopLauncher();
  readonly schedules: ScheduleService = new ScheduleService();
  readonly archive: RunArchive = new RunArchive(this.runs);
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
      this.runs
    );
    // Read at call time: the runtime is built below this line, and the target
    // changes per request.
    executor.registerCapability(new LocalLaunchCapability(
      this.launcher,
      (): boolean => this.runtime.targetRole().length === 0
    ));
    executor.registerCapability(new RemoteUiCapability(this.bridge, gates));
    this.executor = executor;
    this.runtime = new AgentRuntime(
      executor,
      this.memory,
      this.skills,
      this.browser,
      this.bridge,
      new NoAccessibility(),
      new NoBackground(),
      new NoPageLinks(),
      new BridgeScreenSource(this.bridge, gates)
    );
    this.runtime.setHomeAbility('LaptopAbility');
    // No step thumbnails here: the bridge frame is the user's own screen, and
    // taking one right after a launch is what suspended this shell mid-run.
    this.runtime.setCaptureStepFrames(false);
    this.schedules.bindRunner(
      (goal: string): Promise<string> => this.runtime.run(goal),
      (): boolean => this.runtime.isBusy()
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
