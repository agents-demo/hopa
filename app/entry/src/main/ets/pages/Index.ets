import { UIContext } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Context, common } from '@kit.AbilityKit';
import { accessibility } from '@kit.AccessibilityKit';
import { buffer } from '@kit.ArkTS';
import { Action, BatchItemResult, PaymentContext, Screen, Skill } from '@hopa/core';
import { MemoryExtractor } from '@hopa/core';
import { AgentService } from '../service/AgentService';
import { SettingsStore, StoredSettings } from '../service/SettingsStore';
import { MemoryItem } from '../service/MemoryStore';
import { APP_CATALOG, CatalogApp, SITE_CATALOG, CatalogSite } from '../service/AppCatalog';
import { RunRecord } from '@hopa/core';
import { JsSandboxBridge } from '../service/JsSandboxBridge';
import { AppLauncher } from '../service/AppLauncher';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State runCount: number = 0;
  @State a11yAvailable: boolean = false;
  @State a11yInstalled: string = 'checking...';
  @State draft: string = '';
  @State busy: boolean = false;
  @State autonomous: boolean = false;
  @State lastTokens: number = 0;
  @State lastDurationMs: number = 0;
  @State batchText: string = '';
  @State batchResults: BatchItemResult[] = [];
  @State messages: ResourceStr[] = [
    $r('app.string.greeting_1'),
    $r('app.string.greeting_2')
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
  @State runRecords: RunRecord[] = [];
  @State catalogSection: number = 0;
  @State script: string = '';
  @State scriptOutput: string = '';
  @State bridgeUrl: string = '';
  @State bridgeToken: string = '';
  @State bridgeStatus: string = 'not connected';

  private webController: webview.WebviewController = new webview.WebviewController();
  private sandboxController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const service = AgentService.get();
    this.runCount = service.runs.all().length;
    this.a11yAvailable = service.isA11yAvailable();
    this.modelLabel = service.getModelLabel();
    this.initialize();

    // Fail-closed by default; the sheet is the only way to allow an action.
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

  /**
   * ForEach keys must change when the text at an index changes, otherwise the
   * "working..." placeholder is never replaced by the answer.
   */
  private messageKey(item: ResourceStr, index: number): string {
    if (typeof item === 'string') {
      return `${index}-${item}`;
    }
    return `${index}-resource`;
  }

  private async send(): Promise<void> {
    const text: string = this.draft.trim();
    if (text.length === 0 || this.busy) {
      return;
    }
    const fact: string | undefined = MemoryExtractor.extract(text);
    if (fact !== undefined) {
      const item: MemoryItem | undefined = AgentService.get().memory.add(fact);
      if (item !== undefined) {
        this.memoryItems = AgentService.get().memory.all().slice();
        this.saveMemory();
      }
    }
    const service = AgentService.get();
    if (!service.hasModel()) {
      this.messages = this.messages.concat([
        `You: ${text}`,
        $r('app.string.msg_no_model')
      ]);
      this.draft = '';
      return;
    }

    this.draft = '';
    this.busy = true;
    this.taskStatus = 'Running';
    this.messages = this.messages.concat([`You: ${text}`, $r('app.string.msg_working')]);

    const reply: string = await service.run(text);

    // Replace the "working..." line with the real transcript.
    const next: ResourceStr[] = this.messages.slice(0, this.messages.length - 1);
    next.push(`HOPA: ${reply}`);
    this.messages = next;

    this.busy = false;
    this.taskStatus = 'Idle';
    this.lastTokens = service.getLastTokens();
    this.lastDurationMs = service.getLastDurationMs();
    this.refreshRuns();
    this.refreshSkills();
    this.saveSkills();
  }

  private stopRun(): void {
    AgentService.get().cancel();
    this.taskStatus = 'Stopping...';
  }

  private async runContinue(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.taskStatus = 'Continuing';
    const reply: string = await AgentService.get().continueLast();
    this.messages = this.messages.concat([`HOPA: ${reply}`]);
    this.busy = false;
    this.taskStatus = 'Idle';
    this.lastTokens = AgentService.get().getLastTokens();
    this.lastDurationMs = AgentService.get().getLastDurationMs();
    this.refreshRuns();
  }

  private async runBatch(): Promise<void> {
    const goals: string[] = [];
    for (const line of this.batchText.split('\n')) {
      const goal: string = line.trim();
      if (goal.length > 0) {
        goals.push(goal);
      }
    }
    if (goals.length === 0 || this.busy) {
      return;
    }
    this.busy = true;
    this.taskStatus = `Batch: ${goals.length} goals`;
    const results: BatchItemResult[] = await AgentService.get().runBatch(goals);
    this.batchResults = results;
    this.busy = false;
    this.taskStatus = 'Idle';
    this.lastTokens = AgentService.get().getLastTokens();
    this.refreshRuns();
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
    if (this.provider === 'deepseek') {
      return 3;
    }
    return 0;
  }

  /**
   * Serial startup so several preference stores are not opened at once. The
   * emulator froze when six async loads ran concurrently.
   */
  private async initialize(): Promise<void> {
    await this.loadSettings();
    await this.loadBundledKey();
    await this.loadMemory();
    await this.loadSkills();
    await this.loadRuns();
    await this.loadA11yList();
    AgentService.get().setUiLauncher(
      new AppLauncher(getContext(this) as common.UIAbilityContext)
    );
  }

  private async loadSettings(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      this.provider = stored.provider;
      this.modelEndpoint = stored.endpoint;
      this.modelName = stored.model;
      this.networkEnabled = stored.network;
      this.autonomous = stored.autonomous;
      AgentService.get().setNetworkEnabled(stored.network);
      AgentService.get().setAutonomous(stored.autonomous);
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
    stored.autonomous = this.autonomous;
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

  private async exportData(): Promise<void> {
    try {
      const path: string = await AgentService.get().exportData(getContext(this) as Context);
      this.messages = this.messages.concat([
        `HOPA: exported memory, skills and runs to ${path}`
      ]);
    } catch (error) {
      this.messages = this.messages.concat([`HOPA: export failed: ${error}`]);
    }
    this.currentTab = 0;
  }

  private clearMemory(): void {
    AgentService.get().memory.clear();
    this.memoryItems = [];
    this.saveMemory();
    this.messages = this.messages.concat(['HOPA: cleared all remembered facts.']);
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

  private draftLastSkill(): void {
    const skill: Skill | undefined = AgentService.get().saveLastRunAsSkill();
    if (skill !== undefined) {
      this.refreshSkills();
      this.saveSkills();
      this.messages = this.messages.concat([
        `HOPA: saved "${skill.name}" as a skill. Edit it in Memory & skills.`
      ]);
    }
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

  private async loadRuns(): Promise<void> {
    try {
      await AgentService.get().loadRuns(getContext(this) as Context);
      this.runRecords = AgentService.get().runs.all();
      this.runCount = this.runRecords.length;
    } catch (error) {
      // First run: no history yet.
    }
  }

  private refreshRuns(): void {
    this.runRecords = AgentService.get().runs.all();
    this.runCount = this.runRecords.length;
    AgentService.get().saveRuns(getContext(this) as Context).catch(() => {
      // Persistence is best effort.
    });
  }

  private clearRuns(): void {
    AgentService.get().runs.clear();
    this.refreshRuns();
    this.messages = this.messages.concat(['HOPA: cleared the run history.']);
  }

  /**
   * Loads an optional developer key from `rawfile/deepseek.key`.
   *
   * The file is gitignored and exists only in local debug builds. It is never
   * part of a release; production uses Settings and secure storage.
   */
  private async loadBundledKey(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const data = await context.resourceManager.getRawFileContent('deepseek.key');
      const key = buffer.from(data).toString('utf8').trim();
      if (key.length < 10) {
        return;
      }
      this.provider = 'deepseek';
      this.modelEndpoint = 'https://api.deepseek.com/v1';
      this.modelName = 'deepseek-v4-flash';
      this.apiKey = key;
      AgentService.get().configureModel(
        'deepseek',
        this.modelEndpoint,
        key,
        this.modelName,
        6
      );
      this.modelLabel = AgentService.get().getModelLabel();
    } catch (error) {
      // No bundled key: a normal first run.
    }
  }

  private async loadA11yList(): Promise<void> {
    try {
      const list = await accessibility.getAccessibilityExtensionList('all', 'install');
      const names: string[] = [];
      for (const item of list) {
        names.push(`${item.bundleName}/${item.name}`);
      }
      this.a11yInstalled = names.length > 0 ? names.join(', ') : 'none';
    } catch (error) {
      this.a11yInstalled = `error: ${error}`;
    }
  }

  private async connectBridge(): Promise<void> {
    AgentService.get().configureRemote(this.bridgeUrl, this.bridgeToken);
    if (!AgentService.get().isRemoteConfigured()) {
      this.bridgeStatus = 'enter URL and token';
      return;
    }
    this.bridgeStatus = 'checking...';
    const ok: boolean = await AgentService.get().testRemote();
    this.bridgeStatus = ok ? 'connected' : `unreachable: ${AgentService.get().remoteFailure()}`;
    this.messages = this.messages.concat([`HOPA: PC bridge ${this.bridgeStatus}.`]);
  }

  private async runScript(): Promise<void> {
    const code: string = this.script.trim();
    if (code.length === 0) {
      return;
    }
    try {
      const bridge = new JsSandboxBridge(this.sandboxController);
      this.scriptOutput = await bridge.run(code, 'javascript');
    } catch (error) {
      this.scriptOutput = `error: ${error}`;
    }
  }

  private openAddress(): void {
    const url: string = this.address.trim();
    if (!url.startsWith('https://')) {
      this.messages = this.messages.concat([$r('app.string.msg_https_only')]);
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

  private async launchApp(bundle: string, ability: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await context.startAbility({ bundleName: bundle, abilityName: ability });
      this.messages = this.messages.concat([
        `HOPA: opened ${bundle}. To let HOPA read and drive it, accessibility (ACL) must be enabled.`
      ]);
    } catch (error) {
      this.messages = this.messages.concat([`HOPA: could not open ${bundle}: ${error}`]);
    }
    this.currentTab = 0;
  }

  @Builder
  WebPage() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.address, placeholder: 'https://...' })
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
        ? `${this.pageUrl} - ask in Chat, HOPA can read and click this page`
        : 'Load an https page, then ask HOPA in Chat.')
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
        .maxLines(2)

      Row({ space: 8 }) {
        Button($r('app.string.btn_back'))
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            if (this.webController.accessBackward()) {
              this.webController.backward();
            }
          })
        Button($r('app.string.btn_forward'))
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            if (this.webController.accessForward()) {
              this.webController.forward();
            }
          })
        Button($r('app.string.btn_reload'))
          .fontSize(12)
          .height(28)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            this.webController.refresh();
          })
      }
      .width('100%')

      Text('JavaScript sandbox (isolated about:blank page, offline)')
        .fontSize(12)
        .fontColor('#666666')
      TextArea({ placeholder: '1 + 1', text: this.script })
        .height(70)
        .onChange((value: string) => {
          this.script = value;
        })
      Button('Run script')
        .fontSize(12)
        .onClick(() => {
          this.runScript();
        })
      Text(this.scriptOutput)
        .fontSize(11)
        .fontColor('#0A7F3F')
        .maxLines(4)

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

      Web({ src: 'about:blank', controller: this.sandboxController })
        .width(1)
        .height(1)
        .opacity(0)
        .onPageEnd(() => {
          AgentService.get().sandbox.setBridge(new JsSandboxBridge(this.sandboxController));
        })
    }
    .width('100%')
    .height('100%')
    .padding(8)
  }

  @Builder
  AppsListSection() {
    List({ space: 8 }) {
      ForEach(APP_CATALOG, (app: CatalogApp, index: number) => {
        ListItem() {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(app.display)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              if (app.verified && app.ability.length > 0) {
                Button($r('app.string.btn_open'))
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    this.launchApp(app.bundle, app.ability);
                  })
              }
              Text(app.verified
                ? 'bundle verified'
                : (app.confirmed ? 'bundle unverified' : 'no bundle yet'))
                .fontSize(11)
                .fontColor(app.verified ? '#0A7F3F' : (app.confirmed ? '#B26A00' : '#8A8A8A'))
            }
            .width('100%')
            Text(app.bundle.length > 0 ? app.bundle : 'no HarmonyOS bundle yet')
              .fontSize(12)
              .fontColor('#666666')
            if (app.aliases.length > 0) {
              Text(app.aliases.slice(0, 3).join(', '))
                .fontSize(11)
                .fontColor('#999999')
                .maxLines(1)
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)
        }
      }, (app: CatalogApp) => app.name)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  SitesListSection() {
    List({ space: 8 }) {
      ForEach(SITE_CATALOG, (site: CatalogSite, index: number) => {
        ListItem() {
          Column({ space: 2 }) {
            Row({ space: 8 }) {
              Text(site.display)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              if (site.domains.length > 0) {
                Button($r('app.string.btn_open'))
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    this.address = `https://${site.domains[0]}`;
                    this.currentTab = 1;
                    setTimeout(() => {
                      this.openAddress();
                    }, 500);
                  })
              }
            }
            .width('100%')
            Text(site.domains.join(', '))
              .fontSize(12)
              .fontColor('#666666')
            Text(`validated: ${site.validated}`)
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F7F8FA')
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)
        }
      }, (site: CatalogSite) => site.name)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  AppsPage() {
    Column({ space: 10 }) {
      Text(`Catalogue (${APP_CATALOG.length} apps, ${SITE_CATALOG.length} sites)`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        Button(`Apps ${APP_CATALOG.length}`)
          .backgroundColor(this.catalogSection === 0 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.catalogSection === 0 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.catalogSection = 0;
          })
        Button(`Sites ${SITE_CATALOG.length}`)
          .backgroundColor(this.catalogSection === 1 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.catalogSection === 1 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.catalogSection = 1;
          })
      }
      .width('100%')

      Text(this.catalogSection === 0
        ? 'Verified bundles can launch. Unverified and unconfirmed names never launch a guessed bundle.'
        : 'Sites open in the built-in browser. Only https pages are allowed.')
        .fontSize(12)
        .fontColor('#666666')

      if (this.catalogSection === 0) {
        this.AppsListSection()
      } else {
        this.SitesListSection()
      }
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TasksPage() {
    Column({ space: 12 }) {
      Text($r('app.string.title_tasks'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.taskStatus)
        .fontSize(16)
      if (this.busy) {
        Progress({ value: 50, total: 100, type: ProgressType.Linear })
          .width('100%')
      }
      Text(this.a11yAvailable
        ? 'Accessibility is available. The loop can read other apps.'
        : 'Accessibility is unavailable, so the loop can read only the built-in browser.')
        .fontSize(13)
        .fontColor('#666666')

      Text($r('app.string.label_batch'))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      TextArea({ placeholder: $r('app.string.placeholder_batch'), text: this.batchText })
        .height(80)
        .onChange((value: string) => {
          this.batchText = value;
        })
      Row({ space: 8 }) {
        Button($r('app.string.btn_run_batch'))
          .fontSize(12)
          .onClick(() => {
            this.runBatch();
          })
        if (this.busy) {
          Button('Stop')
            .fontSize(12)
            .backgroundColor('#B42318')
            .onClick(() => {
              this.stopRun();
            })
        }
      }
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.batchResults, (item: BatchItemResult, index: number) => {
          ListItem() {
            Column({ space: 2 }) {
              Text(item.goal)
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
              Text(item.output)
                .fontSize(11)
                .maxLines(3)
              Text(`${Math.round(item.durationMs / 1000)}s`)
                .fontSize(10)
                .fontColor('#999999')
            }
            .width('100%')
            .padding(8)
            .backgroundColor('#F7F8FA')
            .borderRadius(6)
            .alignItems(HorizontalAlign.Start)
          }
        }, (item: BatchItemResult, index: number) => `${index}-${item.goal}`)
      }
      .height(140)
      .width('100%')

      Row({ space: 8 }) {
        Text(`Recent actions (${this.runRecords.length})`)
          .fontSize(14)
          .fontColor('#666666')
          .layoutWeight(1)
        if (this.runRecords.length > 0) {
          Button($r('app.string.btn_clear'))
            .fontSize(11)
            .height(26)
            .backgroundColor('#E5E6E8')
            .fontColor('#B42318')
            .onClick(() => {
              this.clearRuns();
            })
        }
      }
      .width('100%')
      Text(`Last run: ${this.lastTokens} tokens | ${(this.lastDurationMs / 1000).toFixed(1)} s`)
        .fontSize(11)
        .fontColor('#999999')
      if (AgentService.get().canDraftSkill()) {
        Button($r('app.string.btn_draft_skill'))
          .fontSize(12)
          .height(30)
          .onClick(() => {
            this.draftLastSkill();
          })
      }
      if (AgentService.get().canContinue()) {
        Button('Continue last task')
          .fontSize(12)
          .height(30)
          .backgroundColor('#E5E6E8')
          .fontColor('#333333')
          .onClick(() => {
            this.runContinue();
          })
      }

      List({ space: 8 }) {
        ForEach(this.runRecords, (run: RunRecord, index: number) => {
          ListItem() {
            Column({ space: 2 }) {
              Row({ space: 8 }) {
                Text(run.kind)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                Text(run.status)
                  .fontSize(12)
                  .fontColor(run.status === 'executed' ? '#0A7F3F' : '#B42318')
              }
              .width('100%')
              Text(run.detail.length > 0 ? run.detail : '(no detail)')
                .fontSize(12)
                .fontColor('#666666')
                .maxLines(2)
            }
            .width('100%')
            .padding(10)
            .backgroundColor('#F7F8FA')
            .borderRadius(8)
            .alignItems(HorizontalAlign.Start)
          }
        }, (run: RunRecord) => run.id)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SettingsPage() {
    Column({ space: 16 }) {
      Text($r('app.string.title_settings'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      Row() {
        Text($r('app.string.label_network'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.networkEnabled })
          .onChange((on: boolean) => {
            this.networkEnabled = on;
            AgentService.get().setNetworkEnabled(on);
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
          .enabled(this.a11yAvailable)
          .onChange((on: boolean) => {
            this.accessibilityEnabled = on;
          })
      }
      .width('100%')

      Row() {
        Text($r('app.string.label_autonomous'))
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.autonomous })
          .onChange((on: boolean) => {
            this.autonomous = on;
            AgentService.get().setAutonomous(on);
            this.persistSettings();
          })
      }
      .width('100%')

      Text('PC bridge (fallback control)')
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.bridgeUrl, placeholder: 'http://192.168.1.10:8765' })
        .onChange((value: string) => {
          this.bridgeUrl = value;
        })
      TextInput({ text: this.bridgeToken, placeholder: 'bridge token' })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.bridgeToken = value;
        })
      Row({ space: 8 }) {
        Button('Connect')
          .fontSize(12)
          .onClick(() => {
            this.connectBridge();
          })
        Text(this.bridgeStatus)
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')
      Text('Run "pc-agent bridge" on the PC. Used only when accessibility is unavailable.')
        .fontSize(11)
        .fontColor('#999999')

      Text($r('app.string.label_provider'))
        .fontSize(14)
        .fontColor('#666666')
      Select([
        { value: 'openai' },
        { value: 'anthropic' },
        { value: 'gemini' },
        { value: 'deepseek' }
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
          } else if (value === 'deepseek') {
            this.modelEndpoint = 'https://api.deepseek.com/v1';
            if (this.modelName === 'gpt-4o-mini' ||
              this.modelName === 'claude-3-5-sonnet-latest' ||
              this.modelName === 'gemini-2.0-flash') {
              this.modelName = 'deepseek-v4-flash';
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

      Text($r('app.string.label_endpoint'))
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.modelEndpoint })
        .onChange((value: string) => {
          this.modelEndpoint = value;
        })

      Text($r('app.string.label_model'))
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.modelName })
        .onChange((value: string) => {
          this.modelName = value;
        })

      Text($r('app.string.label_api_key'))
        .fontSize(14)
        .fontColor('#666666')
      TextInput({ text: this.apiKey, placeholder: 'sk-...' })
        .type(InputType.Password)
        .onChange((value: string) => {
          this.apiKey = value;
        })

      Button(this.modelLabel.length > 0 ? `Save (current: ${this.modelLabel})` : 'Save model settings')
        .onClick(() => {
          this.saveModel();
        })

      Text($r('app.string.label_payment'))
        .fontSize(13)
        .fontColor('#B42318')

      Text(`Installed accessibility services: ${this.a11yInstalled}`)
        .fontSize(11)
        .fontColor('#666666')

      Text($r('app.string.label_sandbox'))
        .fontSize(12)
        .fontColor('#666666')
      Text($r('app.string.label_retention'))
        .fontSize(12)
        .fontColor('#666666')
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
        TextInput({ placeholder: $r('app.string.placeholder_memory'), text: this.memoryDraft })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.memoryDraft = value;
          })
          .onSubmit(() => {
            this.addMemory();
          })
        Button($r('app.string.btn_add'))
          .onClick(() => {
            this.addMemory();
          })
      }
      .width('100%')

      Row({ space: 8 }) {
        Button($r('app.string.btn_export'))
          .fontSize(12)
          .onClick(() => {
            this.exportData();
          })
        Button($r('app.string.btn_clear_facts'))
          .fontSize(12)
          .backgroundColor('#E5E6E8')
          .fontColor('#B42318')
          .onClick(() => {
            this.clearMemory();
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
              Button($r('app.string.btn_delete'))
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
      TextInput({ placeholder: $r('app.string.placeholder_skill_name'), text: this.skillName })
        .onChange((value: string) => {
          this.skillName = value;
        })
      TextInput({ placeholder: $r('app.string.placeholder_trigger'), text: this.skillTrigger })
        .onChange((value: string) => {
          this.skillTrigger = value;
        })
      TextArea({ placeholder: $r('app.string.placeholder_steps'), text: this.skillGuidance })
        .height(90)
        .onChange((value: string) => {
          this.skillGuidance = value;
        })
      Button($r('app.string.btn_save_skill'))
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
                Button($r('app.string.btn_delete'))
                  .fontSize(12)
                  .onClick(() => {
                    this.removeSkill(item.id);
                  })
              }
              .width('100%')
              Text(`when: ${item.trigger}`)
                .fontSize(12)
                .fontColor('#666666')
              Text(`used ${item.uses}, ok ${item.successes}`)
                .fontSize(11)
                .fontColor('#999999')
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
      Text($r('app.string.title_memory'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)

      Row({ space: 8 }) {
        Button($r('app.string.label_facts'))
          .backgroundColor(this.memorySection === 0 ? '#0A59F7' : '#E5E6E8')
          .fontColor(this.memorySection === 0 ? '#FFFFFF' : '#333333')
          .onClick(() => {
            this.memorySection = 0;
          })
        Button($r('app.string.label_skills'))
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
      .tabBar($r('app.string.tab_chat'))

      TabContent() {
        this.WebPage()
      }
      .tabBar($r('app.string.tab_web'))

      TabContent() {
        this.AppsPage()
      }
      .tabBar($r('app.string.tab_apps'))

      TabContent() {
        this.TasksPage()
      }
      .tabBar($r('app.string.tab_tasks'))

      TabContent() {
        this.SettingsPage()
      }
      .tabBar($r('app.string.tab_settings'))

      TabContent() {
        this.MemoryPage()
      }
      .tabBar($r('app.string.tab_memory'))
    }
    .onChange((index: number) => {
      this.currentTab = index;
    })
    .barMode(BarMode.Scrollable)
    .width('100%')
    .height('100%')
  }
}


