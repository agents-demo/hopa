import { AgentService } from '../service/AgentService';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State runCount: number = 0;
  @State a11yAvailable: boolean = false;
  @State draft: string = '';
  @State messages: string[] = [
    'Hi — I am HOPA, your on-device phone agent.',
    'I always ask before any payment.'
  ];
  @State taskStatus: string = 'Idle';
  @State networkEnabled: boolean = false;
  @State accessibilityEnabled: boolean = false;
  @State modelEndpoint: string = 'https://api.openai.com/v1';

  aboutToAppear(): void {
    const service = AgentService.get();
    this.runCount = service.runs.all().length;
    this.a11yAvailable = service.a11y.isAvailable();
  }

  private send(): void {
    const text: string = this.draft.trim();
    if (text.length === 0) {
      return;
    }
    this.messages = this.messages.concat([
      `You: ${text}`,
      'HOPA: (agent loop placeholder — wire core/AgentLoop here)'
    ]);
    this.draft = '';
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
        Button('Send')
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
      Progress({ value: 0, total: 100, type: ProgressType.Linear })
        .width('100%')
      Text('No task is running. Start one from the Chat tab.')
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
