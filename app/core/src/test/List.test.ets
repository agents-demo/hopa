import approvalPolicyTest from './ApprovalPolicy.test';
import actionExecutorTest from './ActionExecutor.test';
import agentLoopTest from './AgentLoop.test';
import toolRegistryTest from './ToolRegistry.test';

export default function testsuite(): void {
  approvalPolicyTest();
  actionExecutorTest();
  agentLoopTest();
  toolRegistryTest();
}
