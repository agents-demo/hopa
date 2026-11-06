import { describe, expect, it } from '@ohos/hypium';
import { Action, Observation, RunRecord } from '../main/ets/Types';
import {
  ActionCapability,
  ActionExecutor,
  ApprovalGateway,
  RunRecorder
} from '../main/ets/ActionExecutor';
import { ApprovalPolicy } from '../main/ets/ApprovalPolicy';
import { AgentLoop } from '../main/ets/AgentLoop';
import { ModelClient, ModelRequest, ModelResponse } from '../main/ets/ModelClient';
import { Screen, ScreenSource } from '../main/ets/Screen';

class FixedApproval implements ApprovalGateway {
  private answer: boolean;
  requests: number = 0;

  constructor(answer: boolean) {
    this.answer = answer;
  }

  async requestApproval(action: Action): Promise<boolean> {
    this.requests++;
    return this.answer;
  }
}

class MemoryRecorder implements RunRecorder {
  records: RunRecord[] = [];

  record(run: RunRecord): void {
    this.records.push(run);
  }
}

class RecordingCapability implements ActionCapability {
  executions: number = 0;

  canHandle(kind: string): boolean {
    return true;
  }

  async execute(action: Action): Promise<Observation> {
    this.executions++;
    return Observation.ok('done');
  }
}

class QueueModel implements ModelClient {
  private replies: string[];
  private index: number = 0;
  requests: ModelRequest[] = [];

  constructor(replies: string[]) {
    this.replies = replies;
  }

  async complete(request: ModelRequest): Promise<ModelResponse> {
    const snapshot = new ModelRequest();
    snapshot.messages = request.messages.slice();
    this.requests.push(snapshot);
    const position: number = Math.min(this.index, this.replies.length - 1);
    const response = new ModelResponse();
    response.text = this.replies[position];
    this.index++;
    return response;
  }
}

class FixedSource implements ScreenSource {
  private screen: Screen;

  constructor(screen: Screen) {
    this.screen = screen;
  }

  async capture(): Promise<Screen> {
    return this.screen;
  }
}

export default function agentLoopTest(): void {
  describe('AgentLoop', () => {
    it('feeds_screen_and_stops_on_denied_payment', 0, async (done: Function) => {
      const source = new FixedSource(new Screen('Checkout\nTotal ¥9.99\nPay now'));
      const model = new QueueModel(['{"kind":"ui.tap"}', '{"kind":"finish"}']);
      const approval = new FixedApproval(false);
      const recorder = new MemoryRecorder();
      const capability = new RecordingCapability();
      const executor = new ActionExecutor(new ApprovalPolicy(), approval, recorder);
      executor.registerCapability(capability);
      const loop = new AgentLoop(executor, model, 5, source);

      const outcomes = await loop.run('pay the order');

      expect(outcomes.length).assertEqual(1);
      expect(outcomes[0].executed).assertFalse();
      expect(approval.requests).assertEqual(1);
      expect(model.requests[0].messages.length).assertEqual(2);
      expect(model.requests[0].messages[1].content.includes('Checkout')).assertTrue();
      done();
    });

    it('finish_stops_without_execution', 0, async (done: Function) => {
      const source = new FixedSource(new Screen('Settings'));
      const model = new QueueModel(['{"kind":"finish"}']);
      const approval = new FixedApproval(true);
      const recorder = new MemoryRecorder();
      const capability = new RecordingCapability();
      const executor = new ActionExecutor(new ApprovalPolicy(), approval, recorder);
      executor.registerCapability(capability);
      const loop = new AgentLoop(executor, model, 5, source);

      const outcomes = await loop.run('do nothing');

      expect(outcomes.length).assertEqual(0);
      expect(capability.executions).assertEqual(0);
      done();
    });
  });
}
