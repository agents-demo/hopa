import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { RunRecord, RunStatus, ScheduledTask, Skill } from '@hopa/core';
import { MemoryItem } from '@hopa/app';
import { window } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { webview } from '@kit.ArkWeb';
import { HopaMark, EmptyHero, StepChips, ChatFormat, Character, KeyStore, SettingsStore, StoredSettings } from '@hopa/app';
import { LaptopChat, LaptopTurn } from '../services/LaptopChat';
import { LaptopAgent, demoApproval } from '../services/LaptopAgent';

import { LaptopSession, LaptopSessions } from '../services/LaptopSessions';
import { LaptopImages } from '../services/LaptopImages';
import { LaptopApp } from '../services/LaptopLauncher';
import { LaptopVoice } from '../services/LaptopVoice';
import { ChatRail, RailHistory } from '../components/ChatRail';
import { CommandPalette } from '../components/CommandPalette';
import { LaptopFirstRun } from '../services/LaptopFirstRun';

const LAPTOP_KEY_ALIAS: string = 'hopa_laptop_key';

/**
 * The HOPA workbench: one conversation, one input, everything else quiet.
 *
 * This shell runs the agent on the laptop itself. It never drives the phone,
 * and it never borrows the phone's key.
 */
class CapabilityRow {
  label: string = '';
  status: string = '';
  detail: string = '';

  constructor(label: string, status: string, detail: string) {
    this.label = label;
    this.status = status;
    this.detail = detail;
  }
}

class UsageRow {
  label: string = '';
  value: string = '';

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

class SessionGroup {
  label: string = '';
  sessions: LaptopSession[] = [];

  constructor(label: string) {
    this.label = label;
  }
}

class PlanChoice {
  label: string = '';
  ms: number = 0;

  constructor(label: string, ms: number) {
    this.label = label;
    this.ms = ms;
  }
}

class RunGroup {
  turnId: string = '';
  question: string = '';
  at: number = 0;
  duration: number = 0;
  failed: number = 0;
  records: RunRecord[] = [];
}

@Entry
@Component
struct LaptopIndex {
  @State turns: LaptopTurn[] = [];
  @State draft: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State keyPresent: boolean = false;
  @State modelName: string = 'deepseek-v4-flash';
  @State provider: string = 'deepseek';
  @State endpoint: string = 'https://api.deepseek.com/v1';
  @State settingsOpen: boolean = false;
  @State keyDraft: string = '';
  @State saved: string = '';
  @State paletteOpen: boolean = false;
  @State lastQuestion: string = '';
  @State sessions: LaptopSession[] = [];
  @State bridgeUrl: string = '';
  @State bridgeToken: string = '';
  @State bridgeStatus: string = '';
  @State bridgeLive: boolean = false;
  @State approvalOpen: boolean = false;
  @State approvalDetail: string = '';
  @State approvalKind: string = '';
  @State approvalFrame: string = '';
  @State listening: boolean = false;
  @State query: string = '';
  @State view: string = 'chat';
  @State runs: RunRecord[] = [];
  @State openRunId: string = '';
  @State openTurn: string = '';
  @State replayTurn: string = '';
  @State replayIndex: number = 0;
  @State undoNote: string = '';
  /** '' acts on this laptop; 'phone' asks the PC bridge to act on the handset. */
  @State targetRole: string = '';
  @State imageTick: number = 0;
  @State plans: ScheduledTask[] = [];
  @State memories: MemoryItem[] = [];
  @State skills: Skill[] = [];
  @State memoryDraft: string = '';
  @State apps: LaptopApp[] = [];
  @State launchNote: string = '';
  @State hoveredSession: string = '';
  @State renameId: string = '';
  @State sidebarOpen: boolean = false;
  @State renameDraft: string = '';
  private ctrlHeld: boolean = false;
  private bridgeTimer: number = -1;
  private images: LaptopImages = new LaptopImages();
  @State planDraft: string = '';
  @State planEvery: number = 3600000;
  @State address: string = LaptopIndex.START_URL;
  private static readonly START_URL: string = 'https://example.com';
  @State pageTitle: string = '';
  @State pageError: string = '';
  @State visited: string[] = [];
  @State pageQuestion: string = '';
  private web: webview.WebviewController = new webview.WebviewController();
  @State speakReplies: boolean = false;
  @State settingsTab: string = 'model';
  @State notifyAnswers: boolean = true;
  @State profileName: string = 'everyday';
  @State kidPin: string = '';
  @State pinPrompt: boolean = false;
  @State pinSetMode: boolean = false;
  @State pinDraft: string = '';
  @State pinError: string = '';
  @State pinIntent: string = '';
  private voice: LaptopVoice = new LaptopVoice();
  @State currentId: string = '';
  private store: LaptopSessions = new LaptopSessions();
  private win: window.Window | undefined = undefined;
  @State maximized: boolean = false;
  @StorageProp('hopa.decorHidden') decorHidden: boolean = false;
  @StorageProp('hopa.laptop.focused') focused: boolean = true;
  @StorageLink('hopa.laptop.cancel') @Watch('onCancelFlag') cancelFlag: string = '';
  @State currentTitle: string = 'HOPA';
  @State lastLatency: number = 0;
  @State lastTokens: number = 0;
  @State winWidth: number = 1280;
  @StorageLink('hopa.laptop.pending') @Watch('onPending') pending: string = '';
  private deferredAsk: string = '';
  private chat: LaptopChat = new LaptopChat();
  private agent: LaptopAgent = new LaptopAgent();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.chat.useRuntime(this.agent.runtime);
    this.store.attachSync(this.agent.chatSync);
    this.chat.onTurnStart = (turnId: string) => {
      this.agent.runs.beginTurn(turnId);
    };
    this.agent.approvals.onAsk = (kind: string, detail: string) => {
      this.approvalKind = kind;
      this.approvalDetail = detail;
      // A frame the run already captured: proof of what the step was about.
      const shots: string[] = this.agent.runtime.stepShots();
      this.approvalFrame = shots.length > 0 ? shots[shots.length - 1] : '';
      this.approvalOpen = true;
    };
    window.getLastWindow(context).then((win: window.Window) => {
      this.win = win;
    }).catch(() => {
      // The system bar remains if the window cannot be reached.
    });
    LaptopSessions.load(context).then((store: LaptopSessions) => {
      this.store = store;
      // The loaded instance replaces the placeholder, so attach again.
      this.store.attachSync(this.agent.chatSync);
      this.store.prune();
      this.store.save(context);
      const session: LaptopSession = store.current();
      this.chat.turns = session.turns.slice();
      this.markInterrupted();
      this.turns = this.chat.turns.slice();
      this.prefetchImages();
      this.lastLatency = session.lastLatency;
      this.lastTokens = session.lastTokens;
      this.refreshSessions();
      this.syncChats();
      // Without this the first publish is silently dropped on a fresh install.
    notificationManager.requestEnableNotification(context).catch(() => {});
    this.agent.launcher.attach(context);
    this.agent.launcher.attachBridge(this.agent.bridge);
    this.images.attach(context, this.agent.chatSync);
      this.agent.launcher.loadInstalled().then(() => {
        this.apps = this.agent.launcher.apps();
      }).catch(() => {
        this.apps = [];
      });
      this.agent.memory.load(context).then(() => {
        this.memories = this.agent.memory.all().slice();
      }).catch(() => {});
      this.agent.skills.load(context).then(() => {
        this.skills = this.agent.skills.all().slice();
      }).catch(() => {});
      this.agent.schedules.load(context).then(() => {
        this.agent.schedules.start();
        this.plans = this.agent.schedules.tasks().slice();
      }).catch(() => {
        this.plans = [];
      });
      this.agent.archive.load(context).then(() => {
        this.runs = this.agent.runs.all().reverse();
      }).catch(() => {
        this.runs = [];
      });
      if ((AppStorage.get<string>('hopa.laptop.new') ?? '') === '1') {
        AppStorage.setOrCreate<string>('hopa.laptop.new', '');
        this.newChat();
      }
      for (let i = this.turns.length - 1; i >= 0; i--) {
        if (this.turns[i].role === 'user') {
          this.lastQuestion = this.turns[i].text;
          break;
        }
      }
    }).catch(() => {
      // An unreadable store is an empty one.
    });
    LaptopFirstRun.ensure(context).then((stored: StoredSettings) => {
      this.endpoint = stored.endpoint;
      this.modelName = stored.model;
      this.provider = stored.provider;
      this.speakReplies = stored.speakReplies;
      this.notifyAnswers = stored.notifyAnswers;
      this.profileName = stored.profile;
      this.kidPin = stored.kidPin;
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        this.agent.configureBridge(stored.bridgeUrl, stored.bridgeToken);
        this.checkBridge();
      }
      KeyStore.load(LAPTOP_KEY_ALIAS).then((key: string) => {
        this.keyPresent = key.length > 0;
        this.chat.configure(this.provider, this.endpoint, this.modelName, key);
        this.applyInjected().then(() => {
          this.runDeferredAsk();
        });
      }).catch(() => {
        // No key yet: the Model panel asks for one.
        this.applyInjected().then(() => {
          this.runDeferredAsk();
        });
      });
    }).catch(() => {
      // Defaults are fine.
    });
    // A pending ask can already be set when the page is created; @Watch only
    // fires on later changes, so read it once here.
    if (this.pending.length > 0) {
      this.onPending();
    }
    const wantedView: string = AppStorage.get<string>('hopa.laptop.view') ?? '';
    if (wantedView.length > 0) {
      AppStorage.setOrCreate<string>('hopa.laptop.view', '');
      this.view = wantedView;
    }
    const pageAsk: string = AppStorage.get<string>('hopa.laptop.pageAsk') ?? '';
    if (pageAsk.length > 0) {
      AppStorage.setOrCreate<string>('hopa.laptop.pageAsk', '');
      this.view = 'browser';
      this.agent.browser.attach(this.web);
      // Let the page settle, then ask about it in place.
      setTimeout(() => {
        this.pageQuestion = pageAsk;
        this.askAboutPage();
      }, 7000);
    }
    if ((AppStorage.get<string>('hopa.laptop.demoApproval') ?? '') === '1') {
      AppStorage.setOrCreate<string>('hopa.laptop.demoApproval', '');
      demoApproval(this.agent);
    }
  }

  /** One button: tap to talk, tap again to send what was heard. */
  private async toggleMic(): Promise<void> {
    if (this.busy) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (this.listening) {
      this.listening = false;
      const heard: string = await this.voice.stop(this.agent);
      if (heard.length > 0) {
        this.draft = heard;
        await this.send();
      } else {
        this.error = this.agent.isBridgeConfigured()
          ? 'I did not catch that. Try again, a little closer.'
          : 'Voice needs the PC bridge: start it, then connect in Settings.';
      }
      return;
    }
    if (!this.agent.isBridgeConfigured()) {
      this.error = 'Voice needs the PC bridge: start it, then connect in Settings.';
      return;
    }
    const started: boolean = await this.voice.start(context);
    this.listening = started;
    if (!started) {
      this.error = 'The microphone is not available.';
    } else {
      this.error = '';
    }
  }

  /** The notification's Stop button lands here through the ability. */
  aboutToDisappear(): void {
    if (this.bridgeTimer >= 0) {
      clearInterval(this.bridgeTimer);
      this.bridgeTimer = -1;
    }
  }

  onCancelFlag(): void {
    if (this.cancelFlag !== '1') {
      return;
    }
    this.cancelFlag = '';
    if (this.busy) {
      this.chat.cancel();
    }
  }

  private copyText(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setData(data).catch(() => {});
    } catch (error) {
      // Clipboard is best effort.
    }
  }

  /** Run records grouped by the conversation turn that caused them. */
  private runGroups(): RunGroup[] {
    const groups: RunGroup[] = [];
    let current: RunGroup | undefined = undefined;
    for (const run of this.runs) {
      const key: string = run.turnId.length > 0 ? run.turnId : 'single';
      if (current === undefined || current.turnId !== key) {
        current = new RunGroup();
        current.turnId = key;
        current.question = this.questionFor(key);
        current.at = run.startedAt;
        groups.push(current);
      }
      current.records.push(run);
      current.duration += run.durationMs;
      if (run.status === RunStatus.Failed) {
        current.failed += 1;
      }
    }
    return groups;
  }

  /** The inverse of a launch: close what HOPA opened, then come back here. */
  private async undoRun(run: RunRecord): Promise<void> {
    if (run.target.length === 0 || run.target === 'com.hopa.agent') {
      this.undoNote = 'Nothing to put back for this step.';
      return;
    }
    this.undoNote = 'Closing\u2026';
    const closed: boolean = await this.agent.bridge.stopApp(run.target);
    await this.agent.bridge.focus('com.hopa.agent', 'LaptopAbility');
    this.undoNote = closed ? `Closed ${run.target}.` : 'The app did not close.';
  }

  private questionFor(turnId: string): string {
    for (const session of this.sessions) {
      for (const turn of session.turns) {
        if (turn.id === turnId && turn.role === 'user') {
          return turn.text;
        }
      }
    }
    return '';
  }

  private replayShots(group: RunGroup): string[] {
    const shots: string[] = [];
    for (const run of group.records) {
      if (run.shot.length > 0) {
        shots.push(run.shot);
      }
    }
    return shots;
  }

  /** The last question in this conversation. */
  private lastUserTurn(): LaptopTurn | undefined {
    for (let i = this.turns.length - 1; i >= 0; i--) {
      if (this.turns[i].role === 'user') {
        return this.turns[i];
      }
    }
    return undefined;
  }

  /**
   * The runs caused by one question.
   *
   * Ids are authoritative when they match; the shared store can re-key a turn,
   * so a run that started between this question and the next one also belongs
   * to it. That keeps the trace attached to the answer even after a merge.
   */
  private runsFor(turn: LaptopTurn): RunRecord[] {
    let nextAt: number = 0;
    for (let i = 0; i < this.turns.length; i++) {
      if (this.turns[i].id === turn.id) {
        if (i + 1 < this.turns.length) {
          nextAt = this.turns[i + 1].at;
        }
        break;
      }
    }
    const until: number = nextAt > 0 ? nextAt : turn.at + 300000;
    const picked: RunRecord[] = [];
    for (const run of this.runs) {
      const sameTurn: boolean = run.turnId.length > 0 && run.turnId === turn.id;
      const inWindow: boolean = turn.at > 0 && run.startedAt >= turn.at - 500 && run.startedAt < until;
      if (sameTurn || inWindow) {
        picked.push(run);
      }
    }
    picked.sort((a: RunRecord, b: RunRecord) => a.startedAt - b.startedAt);
    return picked;
  }

  /** The newest question in this chat that actually caused actions. */
  private paneTurn(): LaptopTurn | undefined {
    for (let i = this.turns.length - 1; i >= 0; i--) {
      const turn: LaptopTurn = this.turns[i];
      if (turn.role === 'user' && this.runsFor(turn).length > 0) {
        return turn;
      }
    }
    return undefined;
  }

  private paneRuns(): RunRecord[] {
    const turn: LaptopTurn | undefined = this.paneTurn();
    return turn === undefined ? [] : this.runsFor(turn);
  }

  /** True when the pane's run belongs to the answer on screen. */
  private paneIsCurrent(): boolean {
    const turn: LaptopTurn | undefined = this.paneTurn();
    const last: LaptopTurn | undefined = this.lastUserTurn();
    if (turn === undefined || last === undefined) {
      return true;
    }
    return turn.id === last.id;
  }

  /** The question behind a run that is not the last answer. */
  private paneContext(): string {
    const turn: LaptopTurn | undefined = this.paneTurn();
    if (turn === undefined || this.paneIsCurrent()) {
      return '';
    }
    return turn.text;
  }

  /** Other actions in this conversation, newest first, so the pane is never a void. */
  private paneHistory(): RailHistory[] {
    const current: LaptopTurn | undefined = this.paneTurn();
    const rows: RailHistory[] = [];
    for (let i = this.turns.length - 1; i >= 0; i--) {
      const turn: LaptopTurn = this.turns[i];
      if (turn.role !== 'user') {
        continue;
      }
      if (current !== undefined && turn.id === current.id) {
        continue;
      }
      const picked: RunRecord[] = this.runsFor(turn);
      if (picked.length === 0) {
        continue;
      }
      const last: RunRecord = picked[picked.length - 1];
      rows.push(new RailHistory(turn.text, last.startedAt, last.status === RunStatus.Executed));
      if (rows.length >= 3) {
        break;
      }
    }
    return rows;
  }

  /** Ask for any frame this conversation carries but this laptop lacks. */
  private prefetchImages(): void {
    const ids: string[] = [];
    for (const turn of this.turns) {
      if (turn.role !== 'assistant') {
        continue;
      }
      const id: string = ChatFormat.metaValue(turn.text, 'shotId');
      if (id.length > 0) {
        ids.push(id);
      }
    }
    if (ids.length === 0) {
      return;
    }
    this.images.ensure(ids).then((changed: boolean) => {
      if (changed) {
        this.imageTick += 1;
      }
    });
  }

  /** The local file for a turn's artefact, or '' until it exists. */
  private shotFor(turn: LaptopTurn): string {
    const tick: number = this.imageTick;
    return tick >= 0 ? this.images.path(ChatFormat.metaValue(turn.text, 'shotId')) : '';
  }

  private isLastAnswer(turn: LaptopTurn): boolean {    for (let i = this.turns.length - 1; i >= 0; i--) {
      if (this.turns[i].role === 'assistant') {
        return this.turns[i].id === turn.id;
      }
    }
    return false;
  }

  /** Step chips survive a cross-device sync; run records do not. */
  private lastAnswerSteps(): string[] {    for (let i = this.turns.length - 1; i >= 0; i--) {
      const turn: LaptopTurn = this.turns[i];
      if (turn.role === 'assistant') {
        if (turn.steps.length > 0) {
          return turn.steps;
        }
        // A phone-run answer keeps its steps in the stored meta line.
        return ChatFormat.stepsOf(turn.text);
      }
    }
    return [];
  }

  private undoableRun(): RunRecord | undefined {
    const picked: RunRecord[] = this.paneRuns();
    for (let i = picked.length - 1; i >= 0; i--) {
      const run: RunRecord = picked[i];
      if (run.kind === 'ui.launch' && run.status === RunStatus.Executed &&
        run.target.length > 0 && run.target !== 'com.hopa.agent') {
        return run;
      }
    }
    return undefined;
  }

  private undoLastRun(): void {
    const run: RunRecord | undefined = this.undoableRun();
    if (run !== undefined) {
      this.undoRun(run);
    }
  }

  /** Recency groups, like every chat list since 2010. */
  private sessionGroups(): SessionGroup[] {
    const now: number = Date.now();
    const today = new SessionGroup('Today');
    const week = new SessionGroup('Previous 7 days');
    const older = new SessionGroup('Earlier');
    for (const session of this.listedSessions()) {
      const age: number = now - session.updated;
      if (age < 20 * 60 * 60 * 1000) {
        today.sessions.push(session);
      } else if (age < 7 * 24 * 60 * 60 * 1000) {
        week.sessions.push(session);
      } else {
        older.sessions.push(session);
      }
    }
    const groups: SessionGroup[] = [];
    if (today.sessions.length > 0) {
      groups.push(today);
    }
    if (week.sessions.length > 0) {
      groups.push(week);
    }
    if (older.sessions.length > 0) {
      groups.push(older);
    }
    return groups;
  }

  private listedSessions(): LaptopSession[] {
    const needle: string = this.query.trim().toLowerCase();
    const shown: LaptopSession[] = [];
    for (const session of this.sessions) {
      if (session.turns.length === 0) {
        continue;
      }
      if (needle.length === 0) {
        shown.push(session);
        continue;
      }
      if (session.title.toLowerCase().includes(needle)) {
        shown.push(session);
        continue;
      }
      for (const turn of session.turns) {
        if (turn.text.toLowerCase().includes(needle)) {
          shown.push(session);
          break;
        }
      }
    }
    return shown;
  }

  /** Ask the bridge for the shared list; it is the store of record. */
  private async syncChats(): Promise<void> {
    if (this.busy || this.chat.busy) {
      return;
    }
    const pinned: string = this.store.currentId;
    await this.store.syncNow();
    if (this.busy || this.chat.busy) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    await this.store.save(context);
    // A merge must not silently switch the conversation you are reading.
    if (pinned.length > 0 && this.store.currentId !== pinned) {
      this.store.select(pinned);
    }
    this.refreshSessions();
    const session: LaptopSession = this.store.current();
    // A pull can be older than a run that just finished on this laptop. Adopt
    // it only when it knows at least as much; otherwise keep the local turns
    // and let the next push carry them over. Losing a finished run to a stale
    // merge is why an action could happen and leave no turn behind.
    if (this.chat.turns.length === 0 || session.turns.length >= this.chat.turns.length) {
      this.chat.turns = session.turns.slice();
      this.turns = session.turns.slice();
    } else {
      this.store.commit(this.turns, this.lastLatency, this.lastTokens);
    }
    this.prefetchImages();
    this.refreshLastQuestion();
  }

  /**
   * A question with no answer means the shell died mid-run - the memory manager
   * reaps it when another app takes the foreground. On return, say that instead
   * of showing a chat that looks like it ignored the request.
   */
  private markInterrupted(): void {
    const turns: LaptopTurn[] = this.chat.turns;
    if (turns.length === 0) {
      return;
    }
    const last: LaptopTurn = turns[turns.length - 1];
    if (last.role !== 'user') {
      return;
    }
    const reply = new LaptopTurn();
    reply.id = `t\u00b7${Date.now()}\u00b7${Math.floor(Math.random() * 1e6)}`;
    reply.at = Date.now();
    reply.role = 'assistant';
    reply.text = 'I was stopped before I could answer: the system suspended me while ' +
      'I was working in another app. Asking again now.';
    turns.push(reply);
    this.store.commit(turns, this.lastLatency, this.lastTokens);
    // Deliberately no automatic resume: the platform freezes this shell whenever
    // it is backgrounded while a run is still executing (verified with the
    // background task granted), so a retry just repeats the same suspend. The
    // notice is the honest end of that turn.
  }

  /**
   * The system suspends this shell ~0.4 s after an action opens another app and
   * recovers it two seconds later. Finishing the question on that return is the
   * only reliable behaviour a third-party 2-in-1 app can offer; the guard stops
   * a second suspend from looping forever.
   */
  private resumeInterrupted(prompt: string): void {
    if (prompt.trim().length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    preferences.getPreferences(context, 'hopa_laptop').then(async (store) => {
      const last = await store.get('resume_at', 0);
      const since: number = typeof last === 'number' ? last : 0;
      if (Date.now() - since < 180000) {
        return;
      }
      await store.put('resume_at', Date.now());
      await store.flush();
      this.whenReady(prompt, Date.now());
    }).catch(() => {});
  }

  /** The rail and the retry both read this; adopted turns must update it. */
  private refreshLastQuestion(): void {
    this.lastQuestion = '';
    for (let index = this.turns.length - 1; index >= 0; index--) {
      if (this.turns[index].role === 'user') {
        this.lastQuestion = this.turns[index].text;
        return;
      }
    }
  }

  private refreshSessions(): void {
    this.sessions = this.store.list.slice();
    this.currentId = this.store.currentId;
    for (const session of this.sessions) {
      if (session.id === this.currentId) {
        // An empty draft is not called HOPA: the hero already says the name.
        this.currentTitle = session.turns.length > 0 ? session.title : 'New chat';
        break;
      }
    }
  }

  private minimizeWindow(): void {
    if (this.win !== undefined) {
      this.win.minimize().catch(() => {});
    }
  }

  private toggleMaximize(): void {
    if (this.win === undefined) {
      return;
    }
    if (this.maximized) {
      this.win.recover().then(() => {
        this.maximized = false;
      }).catch(() => {});
    } else {
      this.win.maximize().then(() => {
        this.maximized = true;
      }).catch(() => {});
    }
  }

  private closeWindow(): void {
    if (this.win !== undefined) {
      this.win.destroyWindow().catch(() => {});
    }
  }

  /** Phone turns carry a [meta] line; the laptop shows the words only. */
  private cleanRemote(text: string): string {
    // One interpretation of a stored message, shared with the phone: the
    // ⟦meta⟧ line (steps/shot) is parsed there, not guessed at here.
    return ChatFormat.textOf(text);
  }

  private focusRoot(): void {
    try {
      focusControl.requestFocus('hopa-root');
    } catch (error) {
      // Focus control is best effort.
    }
  }

  private newChat(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.settingsOpen = false;
    this.sidebarOpen = false;
    this.view = 'chat';
    const current: LaptopSession = this.store.current();
    if (current.turns.length === 0) {
      // Already a blank thread: put the caret where the user will type.
      this.chat.clear();
      this.turns = [];
      this.error = '';
      this.lastQuestion = '';
      this.lastLatency = 0;
      this.lastTokens = 0;
      this.refreshSessions();
      try {
        focusControl.requestFocus('hopa-composer');
      } catch (error) {
        // Focus is best effort.
      }
      return;
    }
    this.store.create();
    this.chat.clear();
    this.turns = [];
    this.error = '';
    this.lastQuestion = '';
    this.lastLatency = 0;
    this.lastTokens = 0;
    this.refreshSessions();
    this.store.save(context);
  }

  private openSession(id: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.settingsOpen = false;
    this.sidebarOpen = false;
    this.view = 'chat';
    this.store.select(id);
    this.store.save(context);
    const session: LaptopSession = this.store.current();
    this.chat.turns = session.turns.slice();
    this.turns = session.turns.slice();
    this.prefetchImages();
    this.lastLatency = session.lastLatency;
    this.lastTokens = session.lastTokens;
    this.error = '';
    this.refreshLastQuestion();
    this.refreshSessions();
  }

  /** Rename is local to the shared store: title is last-writer-wins. */
  private async renameSession(id: string): Promise<void> {
    const title: string = this.renameDraft.trim();
    this.renameId = '';
    this.renameDraft = '';
    if (title.length === 0) {
      return;
    }
    for (const session of this.store.list) {
      if (session.id === id) {
        session.title = title;
        session.updated = Date.now();
        break;
      }
    }
    const context = getContext(this) as common.UIAbilityContext;
    await this.store.save(context);
    this.refreshSessions();
    this.syncChats();
  }

  private deleteSession(id: string): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.store.removeEverywhere(id);
    if (this.store.currentId.length === 0) {
      this.store.create();
    }
    this.store.save(context);
    this.openSession(this.store.currentId);
  }

  /** `aa start --ps hopa.ask`, or a hopa://ask link, asks without typing. */
  onPending(): void {
    const text: string = this.pending;
    if (text.length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>('hopa.laptop.pending', '');
    this.draft = text;
    if (this.chat.isReady()) {
      this.send();
    } else {
      this.deferredAsk = text;
    }
  }

  private runDeferredAsk(): void {
    if (this.deferredAsk.length === 0) {
      return;
    }
    this.draft = this.deferredAsk;
    this.deferredAsk = '';
    this.send();
  }

  /** A scripted first run can pass the key once; it lands in Asset Store and is forgotten. */
  private async applyInjected(): Promise<void> {
    const injectedKey: string = AppStorage.get<string>('hopa.laptop.key') ?? '';
    const injectedEndpoint: string = AppStorage.get<string>('hopa.laptop.endpoint') ?? '';
    const injectedModel: string = AppStorage.get<string>('hopa.laptop.model') ?? '';
    const injectedBridgeUrl: string = AppStorage.get<string>('hopa.laptop.bridgeUrl') ?? '';
    const injectedBridgeToken: string = AppStorage.get<string>('hopa.laptop.bridgeToken') ?? '';
    if (injectedEndpoint.length === 0 && injectedModel.length === 0 && injectedKey.length === 0 &&
      injectedBridgeUrl.length === 0 && injectedBridgeToken.length === 0) {
      return;
    }
    const context = getContext(this) as common.UIAbilityContext;
    if (injectedEndpoint.length > 0 || injectedModel.length > 0) {
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.endpoint = injectedEndpoint.length > 0 ? injectedEndpoint : stored.endpoint;
      stored.model = injectedModel.length > 0 ? injectedModel : stored.model;
      await SettingsStore.save(context, stored);
      this.endpoint = stored.endpoint;
      this.modelName = stored.model;
      AppStorage.setOrCreate<string>('hopa.laptop.endpoint', '');
      AppStorage.setOrCreate<string>('hopa.laptop.model', '');
    }
    if (injectedKey.length > 0) {
      const saved: boolean = await KeyStore.save(injectedKey, LAPTOP_KEY_ALIAS);
      AppStorage.setOrCreate<string>('hopa.laptop.key', '');
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.keyPresent = key.length > 0;
      this.saved = this.keyPresent ? 'Key saved.' : 'Key store unavailable.';
      this.chat.configure(this.provider, this.endpoint, this.modelName, key);
    }
    if (injectedBridgeUrl.length > 0 || injectedBridgeToken.length > 0) {
      const stored: StoredSettings = await SettingsStore.load(context);
      stored.bridgeUrl = injectedBridgeUrl.length > 0 ? injectedBridgeUrl : stored.bridgeUrl;
      stored.bridgeToken = injectedBridgeToken.length > 0 ? injectedBridgeToken : stored.bridgeToken;
      await SettingsStore.save(context, stored);
      AppStorage.setOrCreate<string>('hopa.laptop.bridgeUrl', '');
      AppStorage.setOrCreate<string>('hopa.laptop.bridgeToken', '');
      this.bridgeUrl = stored.bridgeUrl;
      this.bridgeToken = stored.bridgeToken;
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        this.agent.configureBridge(stored.bridgeUrl, stored.bridgeToken);
        this.checkBridge();
      }
    }
  }

  /** Hold the app alive while a run works and the user is in another app. */
  /** The key loads asynchronously; a resume must wait for it, not race it. */
  private whenReady(prompt: string, startedAt: number): void {
    if (this.chat.isReady() && !this.busy) {
      this.draft = prompt;
      this.send();
      return;
    }
    if (Date.now() - startedAt > 15000) {
      this.error = 'Ask again when the model key is loaded.';
      return;
    }
    setTimeout(() => {
      this.whenReady(prompt, startedAt);
    }, 500);
  }

  /**
   * While a run acts in another app, this window stays above it. A shell that
   * is fully covered goes to the background, and the resource scheduler freezes
   * it on a lifecycle timeout, which used to kill the run mid-answer.
   */
  private async enterWorkingWindow(): Promise<void> {
    const win: window.Window | undefined = this.win;
    if (win === undefined) {
      return;
    }
    try {
      await win.setWindowTopmost(true);
    } catch (error) {
      // Not fatal: without it the run may still finish if the app is quick.
    }
  }

  private async leaveWorkingWindow(): Promise<void> {
    const win: window.Window | undefined = this.win;
    if (win === undefined) {
      return;
    }
    try {
      await win.setWindowTopmost(false);
    } catch (error) {
      // Leaving it on top is harmless; the user can move the window.
    }
  }

  private async keepAliveBounded(run: boolean): Promise<void> {
    let timer: number = -1;
    const guard: Promise<void> = new Promise<void>(
      (resolve: (value: void) => void) => {
        timer = setTimeout(resolve, 5000);
      });
    try {
      await Promise.race([this.keepAlive(run), guard]);
    } finally {
      clearTimeout(timer);
    }
  }

  private async keepAlive(run: boolean): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    try {
      if (run) {
        const agent: WantAgent = await wantAgent.getWantAgent({
          wants: [
            {
              bundleName: 'com.hopa.agent',
              abilityName: 'LaptopAbility'
            }
          ],
          actionType: wantAgent.OperationType.START_ABILITY,
          requestCode: 31
        });
        await backgroundTaskManager.startBackgroundRunning(
          context, backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent);
        console.info('HOPA: background task started');
      } else {
        await backgroundTaskManager.stopBackgroundRunning(context);
      }
    } catch (error) {
      // Without it the run still works while HOPA is in front; it is a shield,
      // not a requirement. The code matters: 9800004 says the mode is refused.
      const failure = error as Error;
      console.info(`HOPA: background task failed ${failure.message}`);
    }
  }

  private async send(): Promise<void> {
    if (this.draft.trim().length === 0 || this.busy) {
      return;
    }
    if (!this.chat.isReady()) {
      this.error = 'Add a model key to send. Settings is in the sidebar.';
      return;
    }
    const text: string = this.draft;
    this.draft = '';
    this.busy = true;
    const context = getContext(this) as common.UIAbilityContext;
    // The choice of machine rides on the request, not on the conversation.
    this.agent.runtime.setTarget(this.targetRole);
    // Two shields before the first action, because the first action opens
    // another app: keep the window on top (the scheduler freezes a fully
    // backgrounded shell mid-run) and hold a background task as well.
    await this.enterWorkingWindow();
    await this.keepAliveBounded(true);
    // Show the question at once; waiting for the run made the pane look dead.
    const running: Promise<void> = this.chat.send(text);
    this.turns = this.chat.turns.slice();
    this.prefetchImages();
    this.lastQuestion = this.chat.lastQuestion;
    // The question is in the list now; without this it sits below the fold and
    // looks like the send did nothing.
    this.scrollToEnd();
    // Put the question in the shared store before the model runs. A finished
    // action with no turn behind it has nowhere for its steps or frame to live.
    this.store.commit(this.chat.turns, this.chat.lastLatencyMs, this.chat.lastTokens);
    try {
      await this.store.save(context);
    } catch (error) {
      // The turn is still on screen; the store retries on the next change.
    }
    this.refreshSessions();
    try {
      await this.store.syncNow();
    } catch (error) {
      // The turn is local; a later sync will carry it.
    }
    // A rejected or stalled run must never leave the composer locked with no
    // answer: the first version awaited the run and cleared `busy` only on the
    // happy path, so one bad turn froze the shell until the app was restarted.
    try {
      await running;
    } catch (error) {
      this.error = `${(error as Error).message}`;
    } finally {
      this.keepAlive(false).catch(() => {});
      this.leaveWorkingWindow().catch(() => {});
      this.busy = false;
    }
    this.turns = this.chat.turns.slice();
    this.prefetchImages();
    this.error = this.chat.error.length > 0 ? this.chat.error : this.error;
    this.lastQuestion = this.chat.lastQuestion;
    this.lastLatency = this.chat.lastLatencyMs;
    this.lastTokens = this.chat.lastTokens;
    this.scrollToEnd();
    if (this.speakReplies && this.chat.turns.length > 0) {
      const last = this.chat.turns[this.chat.turns.length - 1];
      if (last.role === 'assistant') {
        this.voice.speak(this.agent, last.text, context);
      }
    }
    if (!this.focused) {
      this.notifyAnswer(text.length > 0 ? this.lastQuestion : 'HOPA');
    }
    this.store.commit(this.chat.turns, this.chat.lastLatencyMs, this.chat.lastTokens);
    await this.store.save(context);
    this.refreshSessions();
    // Push the finished turn; do not adopt here. A pull is a merge of every
    // device and can lag this run by one request, and adopting it would replace
    // the conversation you are looking at — the run would vanish with it.
    try {
      await this.store.syncNow();
    } catch (error) {
      // The run is safe locally; the bridge will get it on the next sync.
    }
    this.runs = this.agent.runs.all().reverse();
    this.agent.archive.save(context);
  }

  /** Ctrl+K opens the palette; Esc closes it. Phone shells never see these. */
  /**
   * Ctrl+K opens the palette, Esc closes whatever is open.
   *
   * The modifier is tracked from its own key events instead of asking the
   * event for modifier state: that call is what took the app down on the 2in1,
   * and a keyboard shortcut must never be able to kill the shell.
   */
  private handleShortcut(event: KeyEvent): boolean {
    try {
      const isCtrl: boolean = event.keyCode === 2072 || event.keyCode === 2073;
      const isMeta: boolean = event.keyCode === 2076 || event.keyCode === 2077;
      if (isCtrl || isMeta) {
        this.ctrlHeld = event.type === KeyType.Down;
        return false;
      }
      if (event.type !== KeyType.Down) {
        return false;
      }
      if (this.ctrlHeld && event.keyCode === 2027) {
        this.paletteOpen = !this.paletteOpen;
        if (!this.paletteOpen) {
          this.focusRoot();
        }
        return true;
      }
      if (event.keyCode === 2070) {
        if (this.paletteOpen) {
          this.paletteOpen = false;
          this.focusRoot();
          return true;
        }
        if (this.settingsOpen) {
          this.settingsOpen = false;
          return true;
        }
      }
      return false;
    } catch (error) {
      return false;
    }
  }

  private scrollToEnd(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom);
      } catch (error) {
        // The list is not mounted (another pane is showing): nothing to scroll.
      }
    }, 60);
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom);
      } catch (error) {
        // Same.
      }
    }, 220);
  }

  /** Save the bridge pair, then ask it a real question: are you there? */
  private async saveBridge(): Promise<void> {
    const url: string = this.bridgeUrl.trim();
    const token: string = this.bridgeToken.trim();
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.bridgeUrl = url;
    stored.bridgeToken = token;
    await SettingsStore.save(context, stored);
    if (url.length === 0 || token.length === 0) {
      this.bridgeLive = false;
      this.bridgeStatus = 'Not connected.';
      return;
    }
    this.agent.configureBridge(url, token);
    await this.checkBridge();
  }

  /** A real request, so the bridge line reports the truth rather than the config. */
  private async checkBridge(): Promise<void> {
    if (!this.agent.isBridgeConfigured()) {
      this.bridgeLive = false;
      this.bridgeStatus = '';
      return;
    }
    this.bridgeStatus = 'Checking\u2026';
    const alive: boolean = await this.agent.testBridge();
    if (!alive) {
      this.bridgeLive = false;
      this.bridgeStatus = `No answer from the bridge. ${this.agent.bridgeFailure()}`;
      return;
    }
    // A port that answers is not a key that works; /whoami proves the token.
    const trusted: boolean = await this.agent.bridge.whoami();
    this.bridgeLive = trusted;
    this.bridgeStatus = trusted
      ? 'Connected.'
      : 'The bridge rejected this key. Copy the current token from the bridge output.';
    if (trusted) {
      this.syncChats();
    }
  }

  /** Speaking replies is a preference, not a model setting. */
  private async saveNotify(value: boolean): Promise<void> {
    this.notifyAnswers = value;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.notifyAnswers = value;
    await SettingsStore.save(context, stored);
  }

  private async saveSpeak(value: boolean): Promise<void> {
    this.speakReplies = value;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.speakReplies = value;
    await SettingsStore.save(context, stored);
  }

  /** A system notification only when the window is not the one in front. */
  private async notifyAnswer(question: string): Promise<void> {
    if (!this.notifyAnswers) {
      return;
    }
    try {
      const agent: WantAgent = await wantAgent.getWantAgent({
        wants: [
          {
            bundleName: 'com.hopa.agent',
            abilityName: 'LaptopAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      const stopAgent: WantAgent = await wantAgent.getWantAgent({
        wants: [
          {
            bundleName: 'com.hopa.agent',
            abilityName: 'LaptopAbility',
            parameters: { 'hopa.cancel': '1' }
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 2,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      const request: notificationManager.NotificationRequest = {
        id: 1,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'HOPA has an answer',
            text: question
          }
        },
        wantAgent: agent,
        actionButtons: [
          { title: 'Stop', wantAgent: stopAgent }
        ]
      };
      notificationManager.publish(request).catch(() => {});
    } catch (error) {
      // Notifications are a courtesy, never a dependency.
    }
  }

  private async saveSettings(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.endpoint = this.endpoint.trim().length > 0 ? this.endpoint.trim() : stored.endpoint;
    stored.model = this.modelName.trim().length > 0 ? this.modelName.trim() : stored.model;
    await SettingsStore.save(context, stored);
    if (this.keyDraft.trim().length > 0) {
      const ok: boolean = await KeyStore.save(this.keyDraft, LAPTOP_KEY_ALIAS);
      this.saved = ok ? 'Saved.' : 'That key looks too short.';
      this.keyDraft = '';
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.keyPresent = key.length > 0;
      this.chat.configure(stored.provider, stored.endpoint, stored.model, key);
    } else {
      this.saved = 'Saved.';
      const key: string = await KeyStore.load(LAPTOP_KEY_ALIAS);
      this.chat.configure(stored.provider, stored.endpoint, stored.model, key);
    }
    this.modelName = stored.model;
    this.endpoint = stored.endpoint;
    this.provider = stored.provider;
  }

  @Builder
  ModeChip(mode: string) {
    Text(mode.charAt(0).toUpperCase() + mode.substring(1))
      .fontSize(11.5)
      .fontColor(this.profileName === mode
        ? $r('app.color.on_primary')
        : $r('app.color.text_secondary'))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.profileName === mode
        ? $r('app.color.primary')
        : $r('app.color.surface'))
      .borderRadius(12)
      .onClick(() => {
        this.setProfile(mode);
      })
  }

  @Builder
  Header() {
    Row({ space: 12 }) {
      HopaMark({ state: 'idle', markSize: 26, interactive: false, body: 'laptop' })
      Column({ space: 1 }) {
        Text(this.currentTitle)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .letterSpacing(-0.2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 320 })
        Text(this.subtitle())
          .fontSize(10)
          .fontColor($r('app.color.text_hint'))
      }
      .alignItems(HorizontalAlign.Start)
      Row()
        .layoutWeight(1)
        .height('100%')
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down && this.win !== undefined) {
            this.win.startMoving().catch(() => {});
          }
        })
        .gesture(TapGesture({ count: 2 }).onAction(() => {
          this.toggleMaximize();
        }))

      // Silence when the link is healthy, as every 2026 shell does; only the
      // exception earns chrome, and it lives beside Settings with the missing
      // key rather than in the title bar.

      if (!this.showSidebar()) {
        Text('\u2630')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(8)
          .onClick(() => {
            this.sidebarOpen = !this.sidebarOpen;
          })
        Text('New')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.surface_alt'))
          .borderRadius(16)
          .onClick(() => {
            this.newChat();
          })
      }
      if (this.decorHidden) {
        Row({ space: 2 }) {
          Text('\u2013')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.minimizeWindow();
            })
          Text(this.maximized ? '\u2750' : '\u25a1')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.toggleMaximize();
            })
          Text('\u00d7')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width(30)
            .height(28)
            .textAlign(TextAlign.Center)
            .borderRadius(6)
            .onClick(() => {
              this.closeWindow();
            })
        }
        .padding({ left: 4, right: 4 })
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 22, right: 22 })
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  FieldLabel(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
  }

  @Builder
  SettingsPanel() {
    Column({ space: 22 }) {
      Row() {
        Text('Settings')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('\u00d7')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .onClick(() => {
            this.settingsOpen = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        ForEach(['model', 'bridge', 'modes', 'about'], (tab: string) => {
          Text(tab.charAt(0).toUpperCase() + tab.substring(1))
            .fontSize(11.5)
            .fontColor(this.settingsTab === tab
              ? $r('app.color.on_primary')
              : $r('app.color.text_secondary'))
            .padding({ left: 11, right: 11, top: 5, bottom: 5 })
            .backgroundColor(this.settingsTab === tab
              ? $r('app.color.primary')
              : $r('app.color.surface'))
            .borderRadius(11)
            .onClick(() => {
              this.settingsTab = tab;
            })
        }, (tab: string) => 'tab-' + tab + this.settingsTab)
      }
      .width('100%')

      if (this.settingsTab === 'model') {
      Column({ space: 8 }) {
        Text('MODEL')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')

        this.FieldLabel('Endpoint')
        TextInput({ text: this.endpoint, placeholder: 'https://api.deepseek.com/v1' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.endpoint = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })
          .onBlur(() => {
            this.saveSettings();
          })

        this.FieldLabel('Model')
        TextInput({ text: this.modelName, placeholder: 'deepseek-v4-flash' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.modelName = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })
          .onBlur(() => {
            this.saveSettings();
          })

        this.FieldLabel(this.keyPresent ? 'API key (stored; leave blank to keep it)' : 'API key')
        TextInput({ text: this.keyDraft, placeholder: this.keyPresent ? 'stored in Asset Store' : 'paste your key' })
          .height(38)
          .fontSize(12.5)
          .type(InputType.Password)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.keyDraft = value;
          })
          .onSubmit(() => {
            this.saveSettings();
          })

        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('Speak replies')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
            Text('Uses the PC voice over the bridge.')
              .fontSize(10.5)
              .fontColor($r('app.color.text_hint'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.speakReplies })
            .selectedColor($r('app.color.primary'))
            .onChange((value: boolean) => {
              this.saveSpeak(value);
            })
        }
        .width('100%')
        .padding({ top: 6 })

        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('Tell me when an answer is ready')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
            Text('Only when HOPA is not the window in front.')
              .fontSize(10.5)
              .fontColor($r('app.color.text_hint'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.notifyAnswers })
            .selectedColor($r('app.color.primary'))
            .onChange((value: boolean) => {
              this.saveNotify(value);
            })
        }
        .width('100%')
        .padding({ top: 2 })

        Text('Changes save when you leave a field. The key lives in Asset Store on this laptop, never in the app package.')
          .fontSize(10.5)
          .lineHeight(16)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
        if (this.saved.length > 0) {
          Text(this.saved)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }

      if (this.settingsTab === 'bridge') {
      Column({ space: 8 }) {
        Text('PC BRIDGE')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')

        Text('Gives HOPA eyes and hands on this laptop: it reads the screen and taps, types or opens apps through a bridge running on a PC connected by USB. Every action still asks you first, and nothing happens while the tunnel is down.')
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')

        this.FieldLabel('Bridge address')
        TextInput({ text: this.bridgeUrl, placeholder: 'http://127.0.0.1:8767' })
          .height(38)
          .fontSize(12.5)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.bridgeUrl = value;
          })
          .onSubmit(() => {
            this.saveBridge();
          })
          .onBlur(() => {
            this.saveBridge();
          })

        Text('Use the HOPA cloud relay \u00b7 hopa-relay.onrender.com')
          .fontSize(10.5)
          .fontColor($r('app.color.primary'))
          .onClick(() => {
            // Fill only, like the phone's wizard: Connect is the decision.
            this.bridgeUrl = 'https://hopa-relay.onrender.com';
          })

        this.FieldLabel('Bridge key')
        TextInput({ text: this.bridgeToken, placeholder: 'from the bridge output' })
          .height(38)
          .fontSize(12.5)
          .type(InputType.Password)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.bridgeToken = value;
          })
          .onSubmit(() => {
            this.saveBridge();
          })

        Row({ space: 12 }) {
          Text('Connect')
            .fontSize(12.5)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .backgroundColor($r('app.color.primary_soft'))
            .borderRadius(14)
            .onClick(() => {
              this.saveBridge();
            })
          if (this.bridgeStatus.length > 0) {
            Text(this.bridgeStatus)
              .fontSize(11)
              .fontColor($r('app.color.text_hint'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }

      if (this.settingsTab === 'modes') {
      Column({ space: 8 }) {
        Text('MODE')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_hint'))
          .letterSpacing(0.8)
          .width('100%')
        Row({ space: 6 }) {
          ForEach(['everyday', 'easy', 'power'], (mode: string) => {
            this.ModeChip(mode)
          }, (mode: string) => 'mode-a-' + mode + (this.profileName === mode))
        }
        .width('100%')
        Row({ space: 6 }) {
          ForEach(['social', 'kid'], (mode: string) => {
            this.ModeChip(mode)
          }, (mode: string) => 'mode-b-' + mode + (this.profileName === mode))
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      }

      if (this.settingsTab === 'about') {
        Column({ space: 6 }) {
          Text('HOPA 0.1.0')
            .fontSize(12.5)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text('Runs on this laptop: chat, the shared conversation store, approvals, voice over the PC bridge, and its own browser.')
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text('HOPA runs here, on this laptop. Payments always ask first.')
            .fontSize(10.5)
            .fontColor($r('app.color.text_hint'))
            .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 28 })
    .backgroundColor($r('app.color.bg'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  NavItem(label: string, target: string) {
    Text(label)
      .fontSize(10.5)
      .fontColor(this.view === target
        ? $r('app.color.text_primary')
        : $r('app.color.text_hint'))
      .focusable(true)
      .onClick(() => {
        this.view = this.view === target ? 'chat' : target;
        if (this.view === 'plans') {
          this.plans = this.agent.schedules.tasks().slice();
        }
      })
  }

  @Builder
  LaunchpadPane() {
    Column({ space: 10 }) {
      Row() {
        Text('Launchpad')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('Apps installed here that HOPA knows')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      if (this.launchNote.length > 0) {
        Text(this.launchNote)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      }

      if (this.apps.length === 0) {
        Text('No known app is installed on this laptop, or the list is still loading.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      } else {
        Grid() {
          ForEach(this.apps, (app: LaptopApp) => {
            GridItem() {
              Column({ space: 6 }) {
                Text(app.label.substring(0, 1).toUpperCase())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary'))
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .backgroundColor($r('app.color.primary_soft'))
                  .borderRadius(10)
                Text(app.label)
                  .fontSize(11)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .height(92)
              .justifyContent(FlexAlign.Center)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
              .onClick(() => {
                this.openApp(app);
              })
            }
          }, (app: LaptopApp) => app.bundle)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .columnsGap(8)
        .rowsGap(8)
        .layoutWeight(1)
        .width('100%')
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  private async openApp(app: LaptopApp): Promise<void> {
    this.launchNote = `Opening ${app.label}\u2026`;
    const opened: boolean = await this.agent.launcher.launch(app.bundle);
    this.launchNote = opened ? `Opened ${app.label}.` : `${app.label} would not open.`;
  }

  @Builder
  CapabilitiesPane() {
    Column({ space: 8 }) {
      Row() {
        Text('Capabilities')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('What this laptop can actually do')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      List({ space: 6 }) {
        ForEach(this.capabilityRows(), (row: CapabilityRow) => {
          ListItem() {
            Column({ space: 3 }) {
              Row({ space: 8 }) {
                Text(row.label)
                  .fontSize(12.5)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text(row.status)
                  .fontSize(9.5)
                  .fontColor(row.status === 'yes'
                    ? $r('app.color.success')
                    : (row.status === 'bridge' ? $r('app.color.warning') : $r('app.color.text_hint')))
                  .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                  .backgroundColor($r('app.color.surface_muted'))
                  .borderRadius(6)
              }
              .width('100%')
              Text(row.detail)
                .fontSize(10.5)
                .lineHeight(15)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }
            .width('100%')
            .padding(10)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(10)
            .alignItems(HorizontalAlign.Start)
          }
        }, (row: CapabilityRow) => row.label + row.status)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  private capabilityRows(): CapabilityRow[] {
    const rows: CapabilityRow[] = [];
    rows.push(new CapabilityRow('Chat and answers', 'yes',
      'Runs the same engine as the phone, on this machine.'));
    rows.push(new CapabilityRow('Approvals', 'yes',
      'Every sensitive action pauses in the right rail and waits for you.'));
    rows.push(new CapabilityRow('Shared conversations', 'yes',
      'One list on both devices, kept by the PC bridge.'));
    rows.push(new CapabilityRow('Voice in and out', 'bridge',
      'Records here; the PC transcribes and speaks.'));
    rows.push(new CapabilityRow('Read this screen, tap and type', 'bridge',
      'Through the PC bridge only; without it HOPA cannot see other windows.'));
    rows.push(new CapabilityRow('Its own browser', 'yes',
      'Opens pages itself and reads their text; no permission needed.'));
    rows.push(new CapabilityRow('Plans and memory', 'yes',
      'Schedules run while HOPA is open; memory and skills are yours to edit.'));
    rows.push(new CapabilityRow('Accessibility tree', 'no',
      'Needs the Huawei ACL, which this device has not been granted.'));
    rows.push(new CapabilityRow('Calls and messages', 'no',
      'A laptop has no telephony. This is phone-only by design.'));
    return rows;
  }

  @Builder
  UsagePane() {
    Column({ space: 10 }) {
      Row() {
        Text('Usage')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('This launch of HOPA')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      ForEach(this.usageRows(), (row: UsageRow) => {
        Row() {
          Text(row.label)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
          Text(row.value)
            .fontSize(12.5)
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }, (row: UsageRow) => row.label + row.value)

      Text('Counts start at zero each launch. The shared store keeps the conversations, not the meter.')
        .fontSize(10.5)
        .lineHeight(16)
        .fontColor($r('app.color.text_hint'))
        .width('100%')
        .padding({ top: 4 })
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  private usageRows(): UsageRow[] {
    const rows: UsageRow[] = [];
    rows.push(new UsageRow('Model', this.modelName.length > 0 ? this.modelName : 'not set'));
    rows.push(new UsageRow('Conversations', `${this.sessions.length}`));
    rows.push(new UsageRow('Last run', this.lastTokens > 0 ? `${this.lastTokens} tokens` : 'none yet'));
    rows.push(new UsageRow('Last duration', this.lastLatency > 0 ? `${this.lastLatency} ms` : 'none yet'));
    rows.push(new UsageRow('Tokens this launch', `${this.chat.totalTokens}`));
    rows.push(new UsageRow('Bridge', this.bridgeLive ? 'connected' : 'off'));
    return rows;
  }

  @Builder
  MemoryPane() {
    Column({ space: 10 }) {
      Row() {
        Text('Memory')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('Facts you asked HOPA to keep')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.memoryDraft, placeholder: 'A fact worth keeping\u2026' })
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.memoryDraft = value;
          })
          .onSubmit(() => {
            this.addMemory();
          })
        Text('Keep')
          .fontSize(12)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(12)
          .onClick(() => {
            this.addMemory();
          })
      }
      .width('100%')

      if (this.memories.length === 0) {
        Text('Nothing kept yet. Memory is only what you add here or ask HOPA to remember.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      } else {
        List({ space: 6 }) {
          ForEach(this.memories, (item: MemoryItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Text(item.text)
                  .fontSize(12.5)
                  .lineHeight(18)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('Forget')
                  .fontSize(10.5)
                  .fontColor($r('app.color.text_secondary'))
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor($r('app.color.surface_muted'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.forgetMemory(item.id);
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
            }
          }, (item: MemoryItem) => item.id + item.text)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SkillsPane() {
    Column({ space: 10 }) {
      Row() {
        Text('Skills')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('What HOPA learned from doing')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      if (this.skills.length === 0) {
        Text('No skills yet. After a run that worked, HOPA can draft one; it appears here with its trigger and its guidance.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      } else {
        List({ space: 6 }) {
          ForEach(this.skills, (skill: Skill) => {
            ListItem() {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(skill.name)
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${skill.successes}/${skill.uses}`)
                    .fontSize(10)
                    .fontColor($r('app.color.text_hint'))
                  Text('Delete')
                    .fontSize(10.5)
                    .fontColor($r('app.color.text_secondary'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor($r('app.color.surface_muted'))
                    .borderRadius(8)
                    .onClick(() => {
                      this.deleteSkill(skill.id);
                    })
                }
                .width('100%')
                Text(`When: ${skill.trigger}`)
                  .fontSize(10.5)
                  .fontColor($r('app.color.text_hint'))
                  .width('100%')
                Text(skill.guidance)
                  .fontSize(11.5)
                  .lineHeight(16)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }
          }, (skill: Skill) => skill.id + skill.name)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  private async addMemory(): Promise<void> {
    if (this.memoryDraft.trim().length === 0) {
      return;
    }
    this.agent.memory.add(this.memoryDraft);
    this.memoryDraft = '';
    const context = getContext(this) as common.UIAbilityContext;
    await this.agent.memory.save(context);
    this.memories = this.agent.memory.all().slice();
  }

  private async forgetMemory(id: string): Promise<void> {
    this.agent.memory.remove(id);
    const context = getContext(this) as common.UIAbilityContext;
    await this.agent.memory.save(context);
    this.memories = this.agent.memory.all().slice();
  }

  private async deleteSkill(id: string): Promise<void> {
    this.agent.skills.remove(id);
    const context = getContext(this) as common.UIAbilityContext;
    await this.agent.skills.save(context);
    this.skills = this.agent.skills.all().slice();
  }

  @Builder
  PlansPane() {
    Column({ space: 10 }) {
      Row() {
        Text('Plans')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('While HOPA is open on this laptop')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.planDraft, placeholder: 'Ask HOPA to do this\u2026' })
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.planDraft = value;
          })
          .onSubmit(() => {
            this.addPlan();
          })
        ForEach(this.planChoices(), (choice: PlanChoice) => {
          Text(choice.label)
            .fontSize(11)
            .fontColor(this.planEvery === choice.ms
              ? $r('app.color.on_primary')
              : $r('app.color.text_secondary'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.planEvery === choice.ms
              ? $r('app.color.primary')
              : $r('app.color.surface'))
            .borderRadius(10)
            .onClick(() => {
              this.planEvery = choice.ms;
            })
        }, (choice: PlanChoice) => 'every-' + choice.ms + this.planEvery)
        Text('Add')
          .fontSize(12)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(12)
          .onClick(() => {
            this.addPlan();
          })
      }
      .width('100%')

      if (this.plans.length === 0) {
        Text('No plans yet. A plan is a question HOPA asks itself on a schedule.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      } else {
        List({ space: 6 }) {
          ForEach(this.plans, (plan: ScheduledTask) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(plan.goal)
                    .fontSize(12.5)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(plan.label())
                    .fontSize(10.5)
                    .fontColor($r('app.color.text_hint'))
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text('Remove')
                  .fontSize(10.5)
                  .fontColor($r('app.color.text_secondary'))
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor($r('app.color.surface_muted'))
                  .borderRadius(8)
                  .onClick(() => {
                    this.removePlan(plan.id);
                  })
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
            }
          }, (plan: ScheduledTask) => plan.id + plan.nextRunAt)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  private planChoices(): PlanChoice[] {
    const choices: PlanChoice[] = [];
    choices.push(new PlanChoice('Hourly', 3600000));
    choices.push(new PlanChoice('Daily', 86400000));
    return choices;
  }

  private async addPlan(): Promise<void> {
    const goal: string = this.planDraft.trim();
    if (goal.length === 0) {
      return;
    }
    this.planDraft = '';
    await this.agent.schedules.add(goal, this.planEvery, 0);
    this.plans = this.agent.schedules.tasks().slice();
  }

  private async removePlan(id: string): Promise<void> {
    await this.agent.schedules.remove(id);
    this.plans = this.agent.schedules.tasks().slice();
  }

  @Builder
  BrowserPane() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text('\u2190')
          .fontSize(14)
          .fontColor($r('app.color.text_hint'))
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.web.backward();
          })
        Text('\u2192')
          .fontSize(14)
          .fontColor($r('app.color.text_hint'))
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.web.forward();
          })
        Text('\u21bb')
          .fontSize(13)
          .fontColor($r('app.color.text_hint'))
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            this.web.refresh();
          })
        TextInput({ text: this.address, placeholder: 'Type an address, then press Enter' })
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(9)
          .onChange((value: string) => {
            this.address = value;
          })
          .onSubmit(() => {
            this.openAddress();
          })
        Text('Close')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .onClick(() => {
            this.view = 'chat';
          })
        Text('Go')
          .fontSize(12)
          .fontColor($r('app.color.primary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary_soft'))
          .borderRadius(12)
          .onClick(() => {
            this.openAddress();
          })
      }
      .width('100%')

      Web({ src: LaptopIndex.START_URL, controller: this.web })
        .layoutWeight(1)
        .width('100%')
        .domStorageAccess(true)
        .onErrorReceive(() => {
          this.pageError = 'This page did not load. Check the connection, or open another address.';
        })
        .onPageEnd(() => {
          // Reading a new src from state re-created the Web view and dropped the
          // shell back to chat; navigation now goes through loadUrl only.
          const url: string = this.web.getUrl();
          this.address = url;
          this.pageTitle = this.web.getTitle();
          this.agent.browser.attach(this.web);
          this.agent.browser.note(url, this.pageTitle);
          this.pageError = '';
          if (url.length > 0 && (this.visited.length === 0 || this.visited[0] !== url)) {
            const recent: string[] = [url];
            for (const seen of this.visited) {
              if (seen !== url && recent.length < 6) {
                recent.push(seen);
              }
            }
            this.visited = recent;
          }
        })

      if (this.visited.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.visited, (url: string) => {
            Text(this.shortUrl(url))
              .fontSize(10)
              .fontColor($r('app.color.text_hint'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(8)
              .onClick(() => {
                this.address = url;
                this.openAddress();
              })
          }, (url: string) => 'visited-' + url)
        }
        .width('100%')
      }

      if (this.pageError.length > 0) {
        Text(this.pageError)
          .fontSize(11)
          .fontColor($r('app.color.danger'))
          .width('100%')
      }

      Row({ space: 8 }) {
        TextInput({ text: this.pageQuestion, placeholder: 'Ask about this page' })
          .layoutWeight(1)
          .height(34)
          .fontSize(12)
          .backgroundColor($r('app.color.surface_muted'))
          .borderRadius(17)
          .onChange((value: string) => {
            this.pageQuestion = value;
          })
          .onSubmit(() => {
            this.askAboutPage();
          })
        Text('Ask')
          .fontSize(12)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(12)
          .onClick(() => {
            this.askAboutPage();
          })
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  /** Ask while the page is still mounted, then show the answer in chat. */
  private async askAboutPage(): Promise<void> {
    const question: string = this.pageQuestion.trim();
    if (question.length === 0 || this.busy) {
      return;
    }
    this.pageQuestion = '';
    this.draft = question;
    await this.send();
    this.view = 'chat';
  }

  /** A chip shows the host and the first path segment, not the whole URL. */
  private shortUrl(url: string): string {
    let clean: string = url.replace('https://', '').replace('http://', '');
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean.length > 32 ? `${clean.substring(0, 32)}\u2026` : clean;
  }

  private openAddress(): void {
    let target: string = this.address.trim();
    if (target.length === 0) {
      return;
    }
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = target.includes('.')
        ? `https://${target}`
        : `https://duckduckgo.com/?q=${encodeURIComponent(target)}`;
    }
    this.address = target;
    this.agent.browser.attach(this.web);
    try {
      this.web.loadUrl(target);
    } catch (error) {
      // The page simply stays as it was.
    }
  }

  @Builder
  ActivityPane() {
    Column({ space: 8 }) {
      Row() {
        Text('Activity')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('Steps this laptop actually took')
          .fontSize(10.5)
          .fontColor($r('app.color.text_hint'))
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })

      if (this.undoNote.length > 0) {
        Text(this.undoNote)
          .fontSize(11)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
      }

      if (this.runGroups().length === 0) {
        Text('Nothing yet. Every action HOPA takes lands here, grouped by the question that caused it.')
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.text_hint'))
          .width('100%')
          .padding({ top: 8 })
      } else {
        List({ space: 8 }) {
          ForEach(this.runGroups(), (group: RunGroup) => {
            ListItem() {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  Column({ space: 2 }) {
                    Text(group.question.length > 0 ? group.question : 'Action')
                      .fontSize(12.5)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(`${group.records.length} step${group.records.length === 1 ? '' : 's'} \u00b7 ${group.duration} ms`)
                      .fontSize(10.5)
                      .fontColor($r('app.color.text_hint'))
                      .width('100%')
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  if (group.failed > 0) {
                    Text(`${group.failed} failed`)
                      .fontSize(10)
                      .fontColor($r('app.color.danger'))
                  }
                  Text(this.openTurn === group.turnId ? '\u2039' : '\u203a')
                    .fontSize(14)
                    .fontColor($r('app.color.text_hint'))
                }
                .width('100%')
                .onClick(() => {
                  this.openTurn = this.openTurn === group.turnId ? '' : group.turnId;
                  this.replayTurn = '';
                })

                if (this.openTurn === group.turnId) {
                  ForEach(group.records, (run: RunRecord) => {
                    Row({ space: 8 }) {
                      Row()
                        .width(6)
                        .height(6)
                        .borderRadius(3)
                        .backgroundColor(run.status === RunStatus.Executed
                          ? $r('app.color.success')
                          : (run.status === RunStatus.Denied
                            ? $r('app.color.warning')
                            : $r('app.color.danger')))
                      Column({ space: 2 }) {
                        Text(run.kind)
                          .fontSize(11.5)
                          .fontColor($r('app.color.text_primary'))
                          .width('100%')
                        if (run.detail.length > 0) {
                          Text(run.detail)
                            .fontSize(10.5)
                            .lineHeight(15)
                            .fontColor($r('app.color.text_secondary'))
                            .width('100%')
                        }
                        if (run.changed.length > 0) {
                          Text(run.changed)
                            .fontSize(10)
                            .fontColor($r('app.color.text_hint'))
                            .width('100%')
                        }
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      Text(`${run.durationMs} ms`)
                        .fontSize(10)
                        .fontColor($r('app.color.text_hint'))
                      if (run.kind === 'ui.launch' && run.target.length > 0 &&
                        run.target !== 'com.hopa.agent') {
                        Text('Undo')
                          .fontSize(10.5)
                          .fontColor($r('app.color.primary'))
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor($r('app.color.primary_soft'))
                          .borderRadius(8)
                          .onClick(() => {
                            this.undoRun(run);
                          })
                      }
                    }
                    .width('100%')
                    .padding({ top: 2, bottom: 2 })
                  }, (run: RunRecord) => run.id + run.kind + run.startedAt)

                  if (this.replayShots(group).length > 0) {
                    Row({ space: 8 }) {
                      Text(this.replayTurn === group.turnId ? 'Hide frames' : 'Replay frames')
                        .fontSize(11)
                        .fontColor($r('app.color.primary'))
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .backgroundColor($r('app.color.primary_soft'))
                        .borderRadius(10)
                        .onClick(() => {
                          this.replayTurn = this.replayTurn === group.turnId ? '' : group.turnId;
                          this.replayIndex = 0;
                        })
                      if (this.replayTurn === group.turnId) {
                        Text(`${this.replayIndex + 1} / ${this.replayShots(group).length}`)
                          .fontSize(10.5)
                          .fontColor($r('app.color.text_hint'))
                        Text('Next')
                          .fontSize(11)
                          .fontColor($r('app.color.primary'))
                          .onClick(() => {
                            const total: number = this.replayShots(group).length;
                            this.replayIndex = (this.replayIndex + 1) % total;
                          })
                      }
                    }
                    .width('100%')

                    if (this.replayTurn === group.turnId) {
                      Image(this.replayShots(group)[this.replayIndex])
                        .width('100%')
                        .height(150)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(8)
                        .border({ width: 1, color: $r('app.color.divider') })
                    }
                  }
                }
              }
              .width('100%')
              .padding(10)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }
          }, (group: RunGroup) => group.turnId + group.at + group.records.length)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  Empty() {
    EmptyHero({
      greeting: '',
      tagline: Character.tagline(this.profileName),
      promise: this.showRail() ? '' : 'Payments always ask first.',
      note: this.keyPresent ? '' : 'Add a model key to start. The key stays on this laptop.',
      titleSize: this.heroTitle(),
      bodySize: this.heroBody(),
      markSize: this.heroMark(),
      animate: true,
      interactive: true,
      body: 'laptop'
    })
  }

  @Builder
  Turn(turn: LaptopTurn) {
    if (turn.role === 'user') {
      Row() {
        Blank()
        Text(turn.text)
          .fontSize(13.5)
          .lineHeight(21)
          .fontColor($r('app.color.on_primary'))
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .constraintSize({ maxWidth: '62%' })
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
    } else {
      Row({ space: 12 }) {
        HopaMark({ state: 'idle', markSize: 22, animate: false, interactive: false, body: 'laptop' })
        Column({ space: 6 }) {
          if (turn.steps.length > 0) {
            StepChips({ steps: turn.steps, dense: true })
          }
          if (ChatFormat.listItems(this.cleanRemote(turn.text)).length > 0) {
            if (ChatFormat.listLead(this.cleanRemote(turn.text)).length > 0) {
              Text(ChatFormat.listLead(this.cleanRemote(turn.text)))
                .fontSize(13.5)
                .lineHeight(22)
                .fontColor($r('app.color.text_primary'))
                .width('100%')
            }
            ForEach(ChatFormat.listItems(this.cleanRemote(turn.text)), (line: string, lineIndex: number) => {
              Row({ space: 10 }) {
                Text(`${lineIndex + 1}`)
                  .fontSize(10)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary'))
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor($r('app.color.primary_soft'))
                  .borderRadius(10)
                Text(line)
                  .fontSize(13.5)
                  .lineHeight(20)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .copyOption(CopyOptions.LocalDevice)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (line: string, lineIndex: number) => `${lineIndex}-${line}`)
          } else {
            Text(this.cleanRemote(turn.text))
              .fontSize(13.5)
              .lineHeight(22)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
          }
          if (this.shotFor(turn).length > 0) {
            Image(`file://${this.shotFor(turn)}`)
              .width('100%')
              .constraintSize({ maxWidth: 420 })
              .aspectRatio(1.5)
              .objectFit(ImageFit.Cover)
              .borderRadius(10)
              .border({ width: 1, color: $r('app.color.divider') })
              .margin({ top: 4 })
          }
          Row({ space: 10 }) {
            Text('HOPA on this laptop')
              .fontSize(9.5)
              .fontColor($r('app.color.text_hint'))
            if (this.isLastAnswer(turn)) {
              Text('Copy')
                .fontSize(9.5)
                .fontColor($r('app.color.text_hint'))
                .hoverEffect(HoverEffect.Highlight)
                .onClick(() => {
                  this.copyText(this.cleanRemote(turn.text));
                })
            }
          }
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  /** The hero scales with the pane: readable on a desk, sane when narrow. */
  private heroMark(): number {
    return Math.min(108, Math.max(64, this.winWidth * 0.085));
  }

  /**
   * The name is never off screen for long — but never twice on one screen:
   * the hero carries it when it is visible, the header carries it otherwise.
   */
  private subtitle(): string {
    if (this.view === 'chat' && this.turns.length === 0 && !this.settingsOpen) {
      return 'Running on this laptop';
    }
    if (this.view === 'activity') {
      return 'HOPA \u00b7 Activity';
    }
    if (this.view === 'plans') {
      return 'HOPA \u00b7 Plans';
    }
    if (this.view === 'memory') {
      return 'HOPA \u00b7 Memory';
    }
    if (this.view === 'skills') {
      return 'HOPA \u00b7 Skills';
    }
    if (this.view === 'usage') {
      return 'HOPA \u00b7 Usage';
    }
    if (this.view === 'abilities') {
      return 'HOPA \u00b7 Capabilities';
    }
    if (this.view === 'launchpad') {
      return 'HOPA \u00b7 Launchpad';
    }
    if (this.view === 'browser') {
      return 'HOPA \u00b7 Browser';
    }
    return 'HOPA \u00b7 Running on this laptop';
  }

  private showSidebar(): boolean {
    // Kid is a different shape of app: one thread, no history browser.
    if (this.profileName === 'kid') {
      return false;
    }
    return this.winWidth >= 640;
  }

  private showRail(): boolean {
    if (this.profileName === 'easy' || this.profileName === 'kid' || this.profileName === 'social') {
      return false;
    }
    if (this.winWidth < 940) {
      return false;
    }
    // The pane earns its width: mount it only when it has something the chat
    // cannot show. Otherwise the conversation keeps the space.
    if (this.approvalOpen || this.busy) {
      return true;
    }
    if (this.paneRuns().length > 0 || this.lastAnswerSteps().length > 0) {
      return true;
    }
    return this.showsMetrics() && this.lastLatency > 0;
  }

  /** Easy and Kid read larger; Power and Social stay tight. */
  private heroTitle(): number {
    if (this.profileName === 'easy' || this.profileName === 'kid') {
      return 40;
    }
    return 34;
  }

  private heroBody(): number {
    if (this.profileName === 'easy' || this.profileName === 'kid') {
      return 19;
    }
    return 16;
  }

  private tileText(): number {
    return this.profileName === 'easy' || this.profileName === 'kid' ? 15 : 13.5;
  }

  /** Message type follows the mode: Easy and Kid read larger, Power tighter. */
  private messageText(): number {
    if (this.profileName === 'easy') {
      return 15;
    }
    if (this.profileName === 'kid') {
      return 16;
    }
    if (this.profileName === 'power') {
      return 13;
    }
    return 13.5;
  }

  /** Power wants the facts; Easy, Kid and Social do not. */
  private showsMetrics(): boolean {
    return this.profileName === 'everyday' || this.profileName === 'power';
  }

  /**
   * Kid is a lock, not wallpaper: leaving it needs the parent PIN, and the
   * first visit asks for one. Without that the mode would be a lie.
   */
  private async setProfile(name: string): Promise<void> {
    if (this.profileName === 'kid' && name !== 'kid') {
      this.askPin(`mode:${name}`);
      return;
    }
    if (name === 'kid' && this.kidPin.length === 0) {
      this.pinSetMode = true;
      this.pinPrompt = true;
      this.pinDraft = '';
      this.pinError = '';
      this.pinIntent = 'mode:kid';
      return;
    }
    await this.writeProfile(name);
  }

  private async writeProfile(name: string): Promise<void> {
    this.profileName = name;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.profile = name;
    await SettingsStore.save(context, stored);
  }

  private async saveKidPin(pin: string): Promise<void> {
    this.kidPin = pin;
    const context = getContext(this) as common.UIAbilityContext;
    const stored: StoredSettings = await SettingsStore.load(context);
    stored.kidPin = pin;
    await SettingsStore.save(context, stored);
  }

  private askPin(intent: string): void {
    this.pinSetMode = false;
    this.pinIntent = intent;
    this.pinDraft = '';
    this.pinError = '';
    this.pinPrompt = true;
  }

  private async confirmPin(): Promise<void> {
    const pin: string = this.pinDraft.trim();
    if (pin.length < 4) {
      this.pinError = 'Use at least four digits.';
      return;
    }
    if (this.pinSetMode) {
      await this.saveKidPin(pin);
      const intent: string = this.pinIntent;
      this.pinPrompt = false;
      this.pinSetMode = false;
      if (intent.startsWith('mode:')) {
        await this.writeProfile(intent.substring(5));
      }
      return;
    }
    if (pin !== this.kidPin) {
      this.pinError = 'That PIN is not right.';
      return;
    }
    const intent: string = this.pinIntent;
    this.pinPrompt = false;
    if (intent === 'settings') {
      this.settingsOpen = true;
      this.view = 'chat';
    } else if (intent.startsWith('mode:')) {
      await this.writeProfile(intent.substring(5));
    }
  }

  private openSettings(): void {
    if (this.profileName === 'kid') {
      this.askPin('settings');
      return;
    }
    this.settingsOpen = !this.settingsOpen;
  }

  @Builder
  Sidebar() {
    Column() {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text('+')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
          Text('New chat')
            .fontSize(12.5)
            .fontColor($r('app.color.text_secondary'))
          Blank()
        }
        .width('100%')
        .height(30)
        .padding({ left: 10, right: 10 })
        .borderRadius(8)
        .focusable(true)
        .onClick(() => {
          this.newChat();
        })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 14, bottom: 8 })

      Scroll() {
        Column({ space: 2 }) {
          Stack({ alignContent: Alignment.End }) {
            TextInput({ text: this.query, placeholder: 'Search' })
              .width('100%')
              .height(34)
              .fontSize(12)
              .backgroundColor($r('app.color.surface_muted'))
              .border({ width: 1, color: $r('app.color.divider') })
              .borderRadius(8)
              .padding({ left: 8, right: 52, top: 0, bottom: 0 })
              .placeholderColor($r('app.color.text_hint'))
              .onChange((value: string) => {
                this.query = value;
              })
            // Decoration, not a button: the hint lives inside the field.
            Text('Ctrl K')
              .fontSize(9.5)
              .fontColor($r('app.color.text_hint'))
              .opacity(0.45)
              .margin({ right: 9 })
              .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .margin({ bottom: 6 })

          Row({ space: 10 }) {
            this.NavItem('Activity', 'activity')
            this.NavItem('Plans', 'plans')
            this.NavItem('Capabilities', 'abilities')
          }
          .width('100%')
          .padding({ left: 4, right: 4, top: 2, bottom: 6 })

          ForEach(this.sessionGroups(), (group: SessionGroup) => {
            Text(group.label.toUpperCase())
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.7)
              .width('100%')
              .padding({ left: 4, top: 8, bottom: 2 })

            ForEach(group.sessions, (session: LaptopSession) => {
              Row({ space: 6 }) {
                Text(session.title)
                  .fontSize(12.5)
                  .fontColor(session.id === this.currentId && this.view === 'chat' && !this.settingsOpen
                    ? $r('app.color.text_primary')
                    : $r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
                if (this.hoveredSession === session.id) {
                  Text('\u22ef')
                    .fontSize(13)
                    .fontColor($r('app.color.text_hint'))
                    .padding({ left: 6, right: 2 })
                    .bindMenu([
                      {
                        value: 'Rename',
                        action: () => {
                          this.renameId = session.id;
                          this.renameDraft = session.title;
                        }
                      },
                      {
                        value: 'Delete',
                        action: () => {
                          this.deleteSession(session.id);
                        }
                      }
                    ])
                }
              }
              .width('100%')
              .height(30)
              .padding({ left: 8, right: 8 })
              .backgroundColor(session.id === this.currentId && this.view === 'chat' && !this.settingsOpen
                ? $r('app.color.surface')
                : Color.Transparent)
              .borderRadius(7)
              .focusable(true)
              .onHover((isHover: boolean) => {
                this.hoveredSession = isHover ? session.id : '';
              })
              .onClick(() => {
                this.openSession(session.id);
              })
            }, (session: LaptopSession) => session.id + session.title)
          }, (group: SessionGroup) => 'group-' + group.label + group.sessions.length)
        }
        .width('100%')
        .padding({ left: 12, right: 12, bottom: 8 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)

      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Image($r('app.media.ic_settings'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
          Text('Settings')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Blank()
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .onClick(() => {
          this.openSettings();
        })
        if (!this.keyPresent) {
          Text('Add a model key')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.primary'))
            .width('100%')
            .padding({ left: 8, top: 4 })
            .onClick(() => {
              this.settingsOpen = true;
            })
        }
        // The exception sits here, beside the missing key, not in the title bar.
        if (!this.bridgeLive) {
          Text('No bridge \u00b7 Set up')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.warning'))
            .width('100%')
            .padding({ left: 8, top: 4 })
            .onClick(() => {
              this.settingsTab = 'bridge';
              this.settingsOpen = true;
            })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .border({ width: { top: 1 }, color: $r('app.color.divider') })
    }
    .width(212)
    .height('100%')
    .backgroundColor($r('app.color.surface_alt'))
    .border({ width: { right: 1 }, color: $r('app.color.divider') })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
    Row() {
      if (this.showSidebar()) {
        this.Sidebar()
      }
      Column() {
        this.Header()
        if (this.view === 'launchpad') {
          this.LaunchpadPane()
        } else if (this.view === 'abilities') {
          this.CapabilitiesPane()
        } else if (this.view === 'usage') {
          this.UsagePane()
        } else if (this.view === 'memory') {
          this.MemoryPane()
        } else if (this.view === 'skills') {
          this.SkillsPane()
        } else if (this.view === 'plans') {
          this.PlansPane()
        } else if (this.view === 'browser') {
          this.BrowserPane()
        } else if (this.view === 'activity') {
          this.ActivityPane()
        } else if (this.settingsOpen) {
          Scroll() {
            Column() {
              this.SettingsPanel()
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
        } else if (this.turns.length === 0) {
          Column() {
            this.Empty()
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.turns, (turn: LaptopTurn, index: number) => {
              ListItem() {
                this.Turn(turn)
              }
              .padding({ top: 10, bottom: 10 })
            }, (turn: LaptopTurn, index: number) => `${turn.id.length > 0 ? turn.id : index}-${index}-${turn.role}`)
            if (this.busy) {
              ListItem() {
                Row({ space: 10 }) {
                  HopaMark({ state: 'thinking', markSize: 18, interactive: false, body: 'laptop' })
                  Text('Thinking\u2026')
                    .fontSize(12)
                    .fontColor($r('app.color.text_hint'))
                }
                .width('100%')
              }
              .padding({ top: 8, bottom: 8 })
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 22, right: 22, bottom: 10 })
          .scrollBar(BarState.Off)
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(10.5)
            .fontColor($r('app.color.danger'))
            .width('100%')
            .padding({ left: 22, right: 22, bottom: 4 })
        }
        if (this.approvalOpen && !this.showRail()) {
          Column({ space: 10 }) {
            Text('HOPA asks first')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_hint'))
              .letterSpacing(0.7)
              .width('100%')
            Text(this.approvalDetail)
              .fontSize(13.5)
              .lineHeight(20)
              .fontColor($r('app.color.text_primary'))
              .width('100%')
            Row({ space: 10 }) {
              Text('Not now')
                .fontSize(12.5)
                .fontColor($r('app.color.text_primary'))
                .padding({ left: 16, right: 16, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.surface_muted'))
                .borderRadius(18)
                .onClick(() => {
                  this.approvalOpen = false;
                  this.agent.approvals.answer(false);
                })
              Text('Allow')
                .fontSize(12.5)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.on_primary'))
                .padding({ left: 18, right: 18, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.primary'))
                .borderRadius(18)
                .onClick(() => {
                  this.approvalOpen = false;
                  this.agent.approvals.answer(true);
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 12, bottom: 6 })
          .alignItems(HorizontalAlign.Start)
        }
        if (this.settingsOpen || this.view !== 'chat') {
          Row()
            .width('100%')
            .height(0)
        } else if (this.turns.length === 0 && this.error.length > 0) {
          Text(this.error)
            .fontSize(11.5)
            .fontColor($r('app.color.danger'))
            .width('100%')
            .padding({ left: 22, right: 22, bottom: 4 })
        } else {
        // The gutter lives on a wrapper Row and the pill fills what is left.
        // width('100%') + padding/margin overflows its parent in ArkUI and the
        // margin gets clipped, which is why earlier attempts looked uninset.
        Row() {
        Row({ space: 6 }) {
          if (this.agent.isBridgeConfigured()) {
            Text(this.targetRole === 'phone' ? 'Phone' : 'Laptop')
              .fontSize(10)
              .fontColor(this.targetRole === 'phone'
                ? $r('app.color.primary')
                : $r('app.color.text_hint'))
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(8)
              .onClick(() => {
                this.targetRole = this.targetRole === 'phone' ? '' : 'phone';
              })
          }
          TextArea({ text: this.draft, placeholder: 'Ask HOPA\u2026' })
            .id('hopa-composer')
            .layoutWeight(1)
            .fontSize(13.5)
            .constraintSize({ minHeight: 44, maxHeight: 132 })
            .backgroundColor(Color.Transparent)
            .padding({ left: 2, right: 2, top: 11, bottom: 11 })
            .onChange((value: string) => {
              this.draft = value;
            })
            // Layered on purpose: the key handler covers a physical keyboard
            // (with Shift for a line break); onSubmit covers Enter arriving
            // through the input method, which some 2-in-1 builds do instead.
            .onSubmit(() => {
              this.send();
            })
            .onKeyEvent((event: KeyEvent) => {
              if (this.handleShortcut(event)) {
                return true;
              }
              if (event.type !== KeyType.Down || event.keyCode !== 2054) {
                return;
              }
              // The chat convention, same as Slack or ChatGPT on a desktop:
              // Enter sends, Shift+Enter starts a new line.
              const shift: boolean = event.getModifierKeyState
                ? event.getModifierKeyState(['shift'])
                : false;
              if (shift) {
                return false;
              }
              this.send();
              return true;
            })
          // One button, three states: speak when the field is empty, send when
          // it is not, stop while a run is going. Two buttons was clutter.
          if (this.busy) {
            Button('Stop')
              .height(44)
              .fontSize(13)
              .backgroundColor($r('app.color.surface_muted'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => {
                this.chat.cancel();
              })
          } else if (this.listening) {
            Button('Stop')
              .height(44)
              .fontSize(13)
              .backgroundColor($r('app.color.surface_alt'))
              .fontColor($r('app.color.danger'))
              .onClick(() => {
                this.toggleMic();
              })
          } else if (this.draft.trim().length > 0) {
            Button('Send')
              .height(44)
              .fontSize(13)
              .backgroundColor($r('app.color.primary'))
              .fontColor($r('app.color.on_primary'))
              .onClick(() => {
                this.send();
              })
          } else {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(7)
                .height(13)
                .borderRadius(4)
                .backgroundColor($r('app.color.text_secondary'))
                .offset({ y: -2 })
              Row()
                .width(13)
                .height(1.6)
                .borderRadius(1)
                .backgroundColor($r('app.color.text_secondary'))
                .offset({ y: 6 })
              Row()
                .width(1.6)
                .height(3)
                .backgroundColor($r('app.color.text_secondary'))
                .offset({ y: 9 })
            }
            .width(44)
            .height(44)
            .borderRadius(22)
            .backgroundColor($r('app.color.surface_muted'))
            .accessibilityText('Talk to HOPA')
            .onClick(() => {
              this.toggleMic();
            })
          }
        }
        .layoutWeight(1)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius(24)
        .padding({ left: 20, right: 8, top: 3, bottom: 3 })
        }
        .width('100%')
        // Same gutter as the message list, so the field starts under the HOPA
        // mark and ends where the answer text ends.
        .padding({ left: 22, right: 22, top: 8, bottom: 18 })
        }
      }
      .layoutWeight(1)
      .height('100%')
      if (this.showRail()) {
        ChatRail({
          runs: this.paneRuns(),
          steps: this.lastAnswerSteps(),
          contextTitle: this.paneContext(),
          history: this.paneHistory(),
          busy: this.busy,
          lastLatency: this.paneIsCurrent() ? this.lastLatency : 0,
          lastTokens: this.paneIsCurrent() ? this.lastTokens : 0,
          bridgeLive: this.bridgeLive,
          metrics: this.showsMetrics(),
          approvalOpen: this.approvalOpen,
          approvalDetail: this.approvalDetail,
          approvalFrame: this.approvalFrame,
          onOpenActivity: () => {
            this.view = 'activity';
          },
          onAllow: () => {
            this.approvalOpen = false;
            this.agent.approvals.answer(true);
          },
          onDeny: () => {
            this.approvalOpen = false;
            this.agent.approvals.answer(false);
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.winWidth = Number(newValue.width.toString());
    })
      if (this.sidebarOpen && !this.showSidebar()) {
        Row() {
          Column() {
            this.Sidebar()
          }
          .width(240)
          .height('100%')
          .backgroundColor($r('app.color.surface_alt'))
          Row()
            .layoutWeight(1)
            .height('100%')
            .backgroundColor('#33000000')
            .onClick(() => {
              this.sidebarOpen = false;
            })
        }
        .width('100%')
        .height('100%')
      }
      if (this.renameId.length > 0) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.renameId = '';
          })
        Column({ space: 10 }) {
          Text('Rename conversation')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          TextInput({ text: this.renameDraft, placeholder: 'Name' })
            .height(38)
            .fontSize(13)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(9)
            .onChange((value: string) => {
              this.renameDraft = value;
            })
            .onSubmit(() => {
              this.renameSession(this.renameId);
            })
          Row({ space: 8 }) {
            Text('Cancel')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(12)
              .onClick(() => {
                this.renameId = '';
              })
            Text('Save')
              .fontSize(12.5)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(12)
              .onClick(() => {
                this.renameSession(this.renameId);
              })
          }
          .width('100%')
        }
        .width(300)
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') })
        .alignItems(HorizontalAlign.Start)
      }
      if (this.pinPrompt) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            // A scrim that swallows taps: leaving Kid is deliberate.
          })
        Column({ space: 10 }) {
          Text(this.pinSetMode ? 'Choose a parent PIN' : 'Grown-ups only')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.pinSetMode
            ? 'Leaving Kid later will ask for this PIN.'
            : 'Enter the parent PIN to carry on.')
            .fontSize(11.5)
            .lineHeight(16)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({ text: this.pinDraft, placeholder: 'PIN' })
            .type(InputType.Number)
            .maxLength(8)
            .height(38)
            .fontSize(14)
            .backgroundColor($r('app.color.surface_muted'))
            .borderRadius(9)
            .onChange((value: string) => {
              this.pinDraft = value;
            })
            .onSubmit(() => {
              this.confirmPin();
            })
          if (this.pinError.length > 0) {
            Text(this.pinError)
              .fontSize(11)
              .fontColor($r('app.color.danger'))
              .width('100%')
          }
          Row({ space: 8 }) {
            Text('Cancel')
              .fontSize(12.5)
              .fontColor($r('app.color.text_primary'))
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.surface_muted'))
              .borderRadius(12)
              .onClick(() => {
                this.pinPrompt = false;
                this.pinSetMode = false;
              })
            Text('Okay')
              .fontSize(12.5)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.on_primary'))
              .padding({ left: 16, right: 16, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.primary'))
              .borderRadius(12)
              .onClick(() => {
                this.confirmPin();
              })
          }
          .width('100%')
        }
        .width(300)
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .border({ width: 1, color: $r('app.color.divider') })
        .alignItems(HorizontalAlign.Start)
      }
      if (this.paletteOpen) {
        CommandPalette({
          onNewChat: () => {
            this.newChat();
          },
          onSettings: () => {
            this.settingsOpen = true;
          },
          onGo: (target: string) => {
            this.view = target;
            if (target === 'plans') {
              this.plans = this.agent.schedules.tasks().slice();
            }
            if (target === 'browser') {
              this.agent.browser.attach(this.web);
            }
          },
          onClose: () => {
            this.paletteOpen = false;
            this.focusRoot();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .id('hopa-root')
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => {
      return this.handleShortcut(event);
    })
  }
}
