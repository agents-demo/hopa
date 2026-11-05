import {
  Action,
  ActionExecutor,
  ApprovalGateway,
  ApprovalPolicy,
  RiskLevel,
  RunStore,
  ToolDescriptor,
  ToolRegistry
} from '@hopa/core';
import { WebCapability } from '@hopa/capability-web';
import { SandboxCapability } from '@hopa/capability-sandbox';
import { A11yCapability } from '@hopa/capability-a11y';
import { SystemCapability } from '@hopa/capability-system';

/**
 * Fail-closed approval gateway. Wire this to an ArkUI approval sheet; until the
 * sheet returns true, every payment/sensitive action is denied.
 */
class UiApprovalGateway implements ApprovalGateway {
  async requestApproval(action: Action): Promise<boolean> {
    return false;
  }
}

/** Process-wide composition root: policy + gate + capabilities + tool registry. */
export class AgentService {
  private static instance: AgentService | undefined = undefined;

  readonly executor: ActionExecutor;
  readonly runs: RunStore;
  readonly tools: ToolRegistry;
  readonly web: WebCapability;
  readonly sandbox: SandboxCapability;
  readonly a11y: A11yCapability;
  readonly system: SystemCapability;

  private constructor() {
    this.runs = new RunStore();
    this.executor = new ActionExecutor(
      new ApprovalPolicy(),
      new UiApprovalGateway(),
      this.runs
    );

    this.web = new WebCapability();
    this.sandbox = new SandboxCapability();
    this.a11y = new A11yCapability();
    this.system = new SystemCapability();

    this.executor.registerCapability(this.web);
    this.executor.registerCapability(this.sandbox);
    this.executor.registerCapability(this.a11y);
    this.executor.registerCapability(this.system);

    this.tools = new ToolRegistry();
    this.tools.register(new ToolDescriptor('web.navigate', 'Navigate the web view', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('web.read', 'Read the current page', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.tap', 'Tap a screen coordinate', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('sandbox.run', 'Run an offline script', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('system.openLink', 'Open an https link', RiskLevel.Read));
    this.tools.register(new ToolDescriptor('ui.sendMessage', 'Send a message', RiskLevel.Sensitive));
    this.tools.register(new ToolDescriptor('payment.confirm', 'Confirm a payment', RiskLevel.Payment));
  }

  static get(): AgentService {
    if (AgentService.instance === undefined) {
      AgentService.instance = new AgentService();
    }
    return AgentService.instance;
  }
}
