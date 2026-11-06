import { promptAction } from '@kit.ArkUI';
import { Action, RiskLevel } from '@hopa/core';
import { AgentService } from '../service/AgentService';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State runCount: number = 0;
  @State a11yAvailable: boolean = false;
  @State draft: string = '';
  @State busy: boolean = false;
  @State messages: string[] = [
    'Hi — I am HOPA, your on-device phone agent.',
    'I always ask before any payment.'
  ];
  @State taskStatus: string = 'Idle';
  @State networkEnabled: boolean = false;
  @State accessibilityEnabled: boolean = false;
  @State modelEndpoint: string = 'https://api.openai.com/v1';
  @State modelName: string = 'gpt-4o-mini';
  @State apiKey: string = '';
  @State modelLabel: string = '';

  aboutToAppear(): void {
    const service = AgentService.get();
    this.runCount = service.runs.all().length;
    this.a11yAvailable = service.isA11yAvailable();
    this.modelLabel = service.getModelLabel();

    // Fail-closed by default; the sheet is the only way to allow an action.
    service.approvals.setHandler(async (action: Action): Promise<boolean> => {
      const payment: boolean = action.kind === 'payment.confirm' || action.isPayment;
      const title: string = payment ? 'Confirm payment?' : 'Allow this action?';
      const message: string = payment
        ? `HOPA wants to run: ${action.kind}\n\n` +
          'This looks like a payment. HOPA cannot verify the amount or merchant yet, ' +
          'so check the next screen yourself before you confirm.\n\nAllow it?'
        : `HOPA wants to run: ${action.kind}\nTarget: ${action.target || '(none)'}\n\nAllow it?`;
      try {
        const result = await promptAction.showDialog({
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
    if (!service.hasModel()) {
      this.messages = this.messages.concat([
        `You: ${text}`,
        'HOPA: no model configured. Open Settings, fill in the endpoint, model and key, then Save.'
      ]);
      this.draft = '';
      return;
    }

    this.draft = '';
    this.busy = true;
    this.taskStatus = 'Running';
    this.messages = this.messages.concat([`You: ${text}`, 'HOPA: working…']);

    const reply: string = await service.run(text);

    // Replace the "working…" line with the real transcript.
    const next: string[] = this.messages.slice(0, this.messages.length - 1);
    next.push(`HOPA: ${reply}`);
    this.messages = next;

    this.busy = false;
    this.taskStatus = 'Idle';
    this.runCount = service.runs.all().length;
  }

  private saveModel(): void {
    const service = AgentService.get();
    service.configureModel(this.modelEndpoint.trim(), this.apiKey, this.modelName.trim(), 6);
    this.modelLabel = service.getModelLabel();
    this.messages = this.messages.concat([
      `HOPA: model set to ${this.modelLabel}. The key stays in memory and is not saved.`
    ]);
  }

  @Builder
  ChatPage() {
    Column({ space: 12 }) {
      List({ space: 8 }) {
        ForEach(this.messages, (item: string, index: number) => {
          ListItem() {
            Text(item)
              .width('100%')
              .padding(12)
              .backgroundColor('#F2F3F5')
              .borderRadius(10)
              .fontSize(15)
          }
        }, (item: string, index: number) => `${index}-${item}`)
      }
      .layoutWeight(1)
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: 'Ask HOPA…', text: this.draft })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.draft = value;
          })
          .onSubmit(() => {
            this.send();
          })
        Button(this.busy ? 'Working…' : 'Send')
          .enabled(!this.busy)
          .onClick(() => {
            this.send();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  @Builder
  TasksPage() {
    Column({ space: 16 }) {
      Text('Task progress')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.taskStatus)
        .fontSize(16)
      Progress({ value: this.busy ? 50 : 0, total: 100, type: ProgressType.Linear })
        .width('100%')
      Text(this.a11yAvailable
        ? 'Accessibility is available. The loop can read the screen.'
        : 'Accessibility is unavailable, so the loop cannot read other apps yet.')
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SettingsPage() {
    Column({ space: 16 }) {
      Text('Settings')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      Row() {
        Text('Allow network for web tasks')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.networkEnabled })
          .onChange((on: boolean) => {
            this.networkEnabled = on;
          })
      }
      .width('100%')

      Row() {
        Text(this.a11yAvailable
          ? 'Accessibility service (available)'
          : 'Accessibility service (requires ACL)')
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.accessibilityEnabled })
          .onChange((on: boolean) => {
            this.accessibilityEnabled = on;
          })
      }
      .width('100%')

      Text('Model endpoint')
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.modelEndpoint })
        .onChange((value: string) => {
          this.modelEndpoint = value;
        })

      Text('Model name')
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.modelName })
        .onChange((value: string) => {
          this.modelName = value;
        })

      Text('API key (kept in memory only, never saved)')
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.apiKey, placeholder: 'sk-…' })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.apiKey = value;
        })

      Button(this.modelLabel.length > 0 ? `Save (current: ${this.modelLabel})` : 'Save model settings')
        .onClick(() => {
          this.saveModel();
        })

      Text('Payment: always requires your confirmation. This cannot be changed.')
        .fontSize(13)
        .fontColor('#B42318')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MemoryPage() {
    Column({ space: 12 }) {
      Text('Memory')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(`Run records appear here once the agent executes actions. Recorded: ${this.runCount}`)
        .fontSize(14)
        .fontColor('#666666')
      List({ space: 8 }) {
        ForEach(['No runs yet'], (item: string, index: number) => {
          ListItem() {
            Text(item)
              .padding(12)
              .width('100%')
              .backgroundColor('#F7F8FA')
              .borderRadius(8)
          }
        }, (item: string, index: number) => `${index}-${item}`)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
      TabContent() {
        this.ChatPage()
      }
      .tabBar('Chat')

      TabContent() {
        this.TasksPage()
      }
      .tabBar('Tasks')

      TabContent() {
        this.SettingsPage()
      }
      .tabBar('Settings')

      TabContent() {
        this.MemoryPage()
      }
      .tabBar('Memory')
    }
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .width('100%')
    .height('100%')
  }
}
