import { UIContext } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { Action, PaymentContext, Screen } from '@hopa/core';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../../services/AgentService';

/** Chat: the transcript, the composer and the approval dialog. */
@Component
export struct ChatPage {
  @State messages: ResourceStr[] = [
    $r('app.string.greeting_1'),
    $r('app.string.greeting_2')
  ];
  @State draft: string = '';
  @State busy: boolean = false;
  private seenVersion: number = -1;
  private timer: number = -1;

  aboutToAppear(): void {
    const service = AgentService.get();
    const context = getContext(this) as Context;
    service.conversations.load(context).then(() => {
      this.render();
      this.sync();
    });
    this.installApproval();
    this.timer = setInterval(() => {
      if (!this.busy && service.conversations.version !== this.seenVersion) {
        this.render();
        this.sync();
      }
    }, 500);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private sync(): void {
    this.seenVersion = AgentService.get().conversations.version;
  }

  private render(): void {
    const next: ResourceStr[] = [
      $r('app.string.greeting_1'),
      $r('app.string.greeting_2')
    ];
    for (const entry of AgentService.get().conversations.entries()) {
      next.push(entry.role === 'user' ? `You: ${entry.text}` : `HOPA: ${entry.text}`);
    }
    this.messages = next;
  }

  private messageKey(item: ResourceStr, index: number): string {
    if (typeof item === 'string') {
      return `${index}-${item}`;
    }
    return `${index}-resource`;
  }

  private installApproval(): void {
    const service = AgentService.get();
    const uiContext: UIContext = this.getUIContext();
    service.approvals.setHandler(async (action: Action, screen: Screen | undefined): Promise<boolean> => {
      const payment: boolean = service.policy.isPayment(action, screen);
      const title: string = payment ? 'Confirm payment?' : 'Allow this action?';
      const context: PaymentContext = service.policy.extractPaymentContext(screen);
      const amount: string = context.amount.length > 0 ? context.amount : 'not visible';
      const merchant: string = context.merchant.length > 0 ? context.merchant : 'not visible';
      const message: string = payment
        ? `HOPA wants to run: ${action.kind}\n\n` +
          `Amount: ${amount}\nMerchant: ${merchant}\n\n` +
          `${context.consequence}\n\n` +
          'Check the next screen yourself before you confirm.\n\nAllow it?'
        : `HOPA wants to run: ${action.kind}\nTarget: ${action.target || '(none)'}\n\nAllow it?`;
      try {
        const result = await uiContext.getPromptAction().showDialog({
          title: title,
          message: message,
          buttons: [
            { text: 'Deny', color: '#666666' },
            { text: 'Allow', color: '#B42318' }
          ]
        });
        return result.index === 1;
      } catch (error) {
        return false;
      }
    });
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim();
    if (text.length === 0 || this.busy) {
      return;
    }
    const service = AgentService.get();
    const context = getContext(this) as Context;
    const fact: string | undefined = MemoryExtractor.extract(text);
    if (fact !== undefined && service.memory.add(fact) !== undefined) {
      service.memory.save(context).catch(() => {
        // Persistence is best effort; memory still works in this session.
      });
    }
    if (!service.hasModel()) {
      this.messages = this.messages.concat([
        `You: ${text}`,
        $r('app.string.msg_no_model')
      ]);
      service.conversations.add('user', text);
      service.conversations.add('assistant', 'No model configured.');
      this.sync();
      this.draft = '';
      return;
    }

    this.draft = '';
    this.busy = true;
    this.messages = this.messages.concat([`You: ${text}`, $r('app.string.msg_working')]);
    service.conversations.add('user', text);
    this.sync();

    const reply: string = await service.run(text);

    const next: ResourceStr[] = this.messages.slice(0, this.messages.length - 1);
    next.push(`HOPA: ${reply}`);
    this.messages = next;
    service.conversations.add('assistant', reply);
    this.sync();
    this.busy = false;
    service.skills.save(context).catch(() => {
      // Persistence is best effort.
    });
  }

  private stopRun(): void {
    AgentService.get().cancel();
  }

  build() {
    Column({ space: 12 }) {
      List({ space: 8 }) {
        ForEach(this.messages, (item: ResourceStr, index: number) => {
          ListItem() {
            Text(item)
              .width('100%')
              .padding(12)
              .backgroundColor('#F2F3F5')
              .borderRadius(10)
              .fontSize(15)
          }
        }, (item: ResourceStr, index: number) => this.messageKey(item, index))
      }
      .layoutWeight(1)
      .width('100%')
      Row({ space: 8 }) {
        TextInput({ placeholder: 'Ask HOPA...', text: this.draft })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.draft = value;
          })
          .onSubmit(() => {
            this.send();
          })
        Button(this.busy ? $r('app.string.btn_stop') : $r('app.string.btn_send'))
          .backgroundColor(this.busy ? '#B42318' : '#0A59F7')
          .onClick(() => {
            if (this.busy) {
              this.stopRun();
            } else {
              this.send();
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }
}
