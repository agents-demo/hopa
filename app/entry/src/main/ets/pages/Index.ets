import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Context } from '@kit.AbilityKit';
import { Action, PaymentContext, Screen } from '@hopa/core';
import { AgentService } from '../service/AgentService';
import { SettingsStore, StoredSettings } from '../service/SettingsStore';
import { MemoryItem } from '../service/MemoryStore';
import { Skill } from '@hopa/core';

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
  @State provider: string = 'openai';
  @State apiKey: string = '';
  @State modelLabel: string = '';
  @State address: string = 'https://example.com';
  @State pageUrl: string = '';
  @State memoryDraft: string = '';
  @State memoryItems: MemoryItem[] = [];
  @State memorySection: number = 0;
  @State skillName: string = '';
  @State skillTrigger: string = '';
  @State skillGuidance: string = '';
  @State skills: Skill[] = [];

  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const service = AgentService.get();
    this.runCount = service.runs.all().length;
    this.a11yAvailable = service.isA11yAvailable();
    this.modelLabel = service.getModelLabel();
    this.loadSettings();
    this.loadMemory();
    this.loadSkills();

    // Fail-closed by default; the sheet is the only way to allow an action.
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
    service.configureModel(
      this.provider,
      this.modelEndpoint.trim(),
      this.apiKey,
      this.modelName.trim(),
      6
    );
    this.modelLabel = service.getModelLabel();
    this.persistSettings();
    this.messages = this.messages.concat([
      `HOPA: ${this.provider} model set to ${this.modelLabel}. ` +
        'The key stays in memory and is not saved.'
    ]);
  }

  private providerIndex(): number {
    if (this.provider === 'anthropic') {
      return 1;
    }
    if (this.provider === 'gemini') {
      return 2;
    }
    return 0;
  }

  private async loadSettings(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.provider = stored.provider;
      this.modelEndpoint = stored.endpoint;
      this.modelName = stored.model;
      this.networkEnabled = stored.network;
    } catch (error) {
      // First run or an unreadable store: keep the defaults.
    }
  }

  private persistSettings(): void {
    const stored = new StoredSettings();
    stored.provider = this.provider;
    stored.endpoint = this.modelEndpoint;
    stored.model = this.modelName;
    stored.network = this.networkEnabled;
    SettingsStore.save(getContext(this) as Context, stored).catch(() => {
      // Persistence is best effort; the in-memory settings still work.
    });
  }

  private addMemory(): void {
    const item: MemoryItem | undefined = AgentService.get().memory.add(this.memoryDraft);
    if (item === undefined) {
      return;
    }
    this.memoryDraft = '';
    this.memoryItems = AgentService.get().memory.all().slice();
    this.saveMemory();
    this.messages = this.messages.concat([`HOPA: remembered: ${item.text}`]);
  }

  private removeMemory(id: string): void {
    if (AgentService.get().memory.remove(id)) {
      this.memoryItems = AgentService.get().memory.all().slice();
      this.saveMemory();
    }
  }

  private async loadMemory(): Promise<void> {
    try {
      await AgentService.get().memory.load(getContext(this) as Context);
      this.memoryItems = AgentService.get().memory.all().slice();
    } catch (error) {
      // First run: no memory yet.
    }
  }

  private saveMemory(): void {
    AgentService.get().memory.save(getContext(this) as Context).catch(() => {
      // Persistence is best effort; memory still works in this session.
    });
  }

  private addSkill(): void {
    const skill: Skill | undefined = AgentService.get().skills.add(
      this.skillName,
      this.skillTrigger,
      this.skillGuidance
    );
    if (skill === undefined) {
      return;
    }
    this.skillName = '';
    this.skillTrigger = '';
    this.skillGuidance = '';
    this.refreshSkills();
    this.saveSkills();
    this.messages = this.messages.concat([`HOPA: saved skill "${skill.name}".`]);
  }

  private removeSkill(id: string): void {
    if (AgentService.get().skills.remove(id)) {
      this.refreshSkills();
      this.saveSkills();
    }
  }

  private refreshSkills(): void {
    this.skills = AgentService.get().skills.all().slice();
  }

  private async loadSkills(): Promise<void> {
    try {
      await AgentService.get().skills.load(getContext(this) as Context);
      this.refreshSkills();
    } catch (error) {
      // First run: no skills yet.
    }
  }

  private saveSkills(): void {
    AgentService.get().skills.save(getContext(this) as Context).catch(() => {
      // Persistence is best effort.
    });
  }

  private openAddress(): void {
    const url: string = this.address.trim();
    if (!url.startsWith('https://')) {
      this.messages = this.messages.concat(['HOPA: only https:// pages are allowed in the browser.']);
      return;
    }
    try {
      this.webController.loadUrl(url);
      this.pageUrl = url;
    } catch (error) {
      this.messages = this.messages.concat([`HOPA: browser error: ${error}`]);
    }
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
  WebPage() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.address, placeholder: 'https://…' })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.address = value;
          })
          .onSubmit(() => {
            this.openAddress();
          })
        Button('Go')
          .onClick(() => {
            this.openAddress();
          })
      }
      .width('100%')

      Text(this.pageUrl.length > 0
        ? `${this.pageUrl} — ask in Chat, HOPA can read and click this page`
        : 'Load an https page, then ask HOPA in Chat.')
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
        .maxLines(2)

      Web({ src: 'https://example.com', controller: this.webController })
        .layoutWeight(1)
        .width('100%')
        .onPageEnd(() => {
          try {
            this.pageUrl = this.webController.getUrl();
          } catch (error) {
            this.pageUrl = this.address;
          }
          AgentService.get().browser.attach(this.webController);
        })
    }
    .width('100%')
    .height('100%')
    .padding(8)
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
            this.persistSettings();
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

      Text('Model provider')
        .fontSize(14)
        .fontColor('#666666')
      Select([
        { value: 'openai' },
        { value: 'anthropic' },
        { value: 'gemini' }
      ])
        .selected(this.providerIndex())
        .value(this.provider)
        .onSelect((index: number, value: string) => {
          this.provider = value;
          if (value === 'anthropic') {
            if (this.modelEndpoint === 'https://api.openai.com/v1') {
              this.modelEndpoint = 'https://api.anthropic.com';
            }
            if (this.modelName === 'gpt-4o-mini') {
              this.modelName = 'claude-3-5-sonnet-latest';
            }
          } else if (value === 'gemini') {
            if (this.modelEndpoint === 'https://api.openai.com/v1' ||
              this.modelEndpoint === 'https://api.anthropic.com') {
              this.modelEndpoint = 'https://generativelanguage.googleapis.com';
            }
            if (this.modelName === 'gpt-4o-mini' || this.modelName === 'claude-3-5-sonnet-latest') {
              this.modelName = 'gemini-2.0-flash';
            }
          } else {
            if (this.modelEndpoint === 'https://api.anthropic.com' ||
              this.modelEndpoint === 'https://generativelanguage.googleapis.com') {
              this.modelEndpoint = 'https://api.openai.com/v1';
            }
            if (this.modelName === 'claude-3-5-sonnet-latest' || this.modelName === 'gemini-2.0-flash') {
              this.modelName = 'gpt-4o-mini';
            }
          }
          this.persistSettings();
        })

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
  FactsSection() {
    Column({ space: 12 }) {
      Text('Only what you type here is stored. It is added to HOPA\'s prompt; delete anything you do not want kept.')
        .fontSize(13)
        .fontColor('#666666')

      Row({ space: 8 }) {
        TextInput({ placeholder: 'e.g. I prefer aisle seats', text: this.memoryDraft })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.memoryDraft = value;
          })
          .onSubmit(() => {
            this.addMemory();
          })
        Button('Add')
          .onClick(() => {
            this.addMemory();
          })
      }
      .width('100%')

      List({ space: 8 }) {
        ForEach(this.memoryItems, (item: MemoryItem, index: number) => {
          ListItem() {
            Row({ space: 8 }) {
              Text(item.text)
                .layoutWeight(1)
                .fontSize(14)
              Button('Delete')
                .fontSize(12)
                .onClick(() => {
                  this.removeMemory(item.id);
                })
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#F7F8FA')
            .borderRadius(8)
          }
        }, (item: MemoryItem) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SkillsSection() {
    Column({ space: 10 }) {
      Text('A skill is a procedure HOPA follows when your request contains the trigger words.')
        .fontSize(13)
        .fontColor('#666666')
      TextInput({ placeholder: 'Skill name, e.g. Book a table', text: this.skillName })
        .onChange((value: string) => {
          this.skillName = value;
        })
      TextInput({ placeholder: 'Trigger words, e.g. book a table', text: this.skillTrigger })
        .onChange((value: string) => {
          this.skillTrigger = value;
        })
      TextArea({ placeholder: 'Steps to follow', text: this.skillGuidance })
        .height(90)
        .onChange((value: string) => {
          this.skillGuidance = value;
        })
      Button('Save skill')
        .onClick(() => {
          this.addSkill();
        })

      List({ space: 8 }) {
        ForEach(this.skills, (item: Skill, index: number) => {
          ListItem() {
            Column({ space: 4 }) {
              Row({ space: 8 }) {
                Text(item.name)
                  .fontWeight(FontWeight.Bold)
                  .fontSize(14)
                  .layoutWeight(1)
                Button('Delete')
                  .fontSize(12)
                  .onClick(() => {
                    this.removeSkill(item.id);
                  })
              }
              .width('100%')
              Text(`when: ${item.trigger}`)
                .fontSize(12)
                .fontColor('#666666')
              Text(item.guidance)
                .fontSize(13)
                .maxLines(4)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#F7F8FA')
            .borderRadius(8)
            .alignItems(HorizontalAlign.Start)
          }
        }, (item: Skill) => item.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MemoryPage() {
    Column({ space: 12 }) {
      Text('Memory & skills')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        Button('Facts')
          .backgroundColor(this.memorySection === 0 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.memorySection === 0 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.memorySection = 0;
          })
        Button('Skills')
          .backgroundColor(this.memorySection === 1 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.memorySection === 1 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.memorySection = 1;
          })
      }
      .width('100%')

      if (this.memorySection === 0) {
        this.FactsSection()
      } else {
        this.SkillsSection()
      }

      Text(`Runs recorded: ${this.runCount}`)
        .fontSize(12)
        .fontColor('#666666')
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
        this.WebPage()
      }
      .tabBar('Web')

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
    .barMode(BarMode.Scrollable)
    .width('100%')
    .height('100%')
  }
}
