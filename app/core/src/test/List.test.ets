import approvalPolicyTest from './ApprovalPolicy.test';
import actionExecutorTest from './ActionExecutor.test';
import agentLoopTest from './AgentLoop.test';
import toolRegistryTest from './ToolRegistry.test';
import skillsTest from './Skills.test';
import contextBudgetTest from './ContextBudget.test';

export default function testsuite(): void {
  approvalPolicyTest();
  actionExecutorTest();
  agentLoopTest();
  toolRegistryTest();
  skillsTest();
  contextBudgetTest();
}
