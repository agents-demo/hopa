import approvalPolicyTest from './ApprovalPolicy.test';
import actionExecutorTest from './ActionExecutor.test';
import agentLoopTest from './AgentLoop.test';
import toolRegistryTest from './ToolRegistry.test';
import skillsTest from './Skills.test';
import contextBudgetTest from './ContextBudget.test';
import batchRunnerTest from './BatchRunner.test';
import skillDrafterTest from './SkillDrafter.test';
import memoryExtractorTest from './MemoryExtractor.test';
import screenTest from './Screen.test';
import schedulesTest from './Schedules.test';
import chatHistoryTest from './ChatHistory.test';
import appRouterTest from './AppRouter.test';
import runNarratorTest from './RunNarrator.test';
import approvalDescriptionTest from './ApprovalDescription.test';

export default function testsuite(): void {
  approvalPolicyTest();
  actionExecutorTest();
  agentLoopTest();
  toolRegistryTest();
  skillsTest();
  contextBudgetTest();
  batchRunnerTest();
  skillDrafterTest();
  memoryExtractorTest();
  screenTest();
  schedulesTest();
  chatHistoryTest();
  appRouterTest();
  runNarratorTest();
  approvalDescriptionTest();
}
