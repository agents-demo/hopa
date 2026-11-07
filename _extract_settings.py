from pathlib import Path

p = Path("apps/harmony/entry/src/main/ets/pages/Index.ets")
text = p.read_text(encoding="utf-8")


def cut(start_marker: str, end_marker: str) -> None:
    global text
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end <= start:
        raise SystemExit(f"marker not found: {start_marker[:45]!r} / {end_marker[:45]!r}")
    text = text[:start] + text[end:]


text = text.replace(
    "import { ScreensPage } from './tools/ScreensPage';",
    "import { SettingsPage } from './settings/SettingsPage';\nimport { ScreensPage } from './tools/ScreensPage';",
)
text = text.replace(
    "    } else if (this.activePage === 'settings') {\n      this.SettingsHost()",
    "    } else if (this.activePage === 'settings') {\n      SettingsPage()",
)

cut("  @Builder\n  SettingsPage() {", "  private pageTitle(): string {")
cut("  @Builder\n  SettingsHost() {", "  @Builder\n  AppAccessPage() {")
cut("  @Builder\n  AppAccessPage() {", "\n  build() {")

cut("  private saveModel(): void {", "  private async initialize(): Promise<void> {")
cut("  private async loadSettings(): Promise<void> {", "  private async loadSchedules(): Promise<void> {")
cut("  private clearRuns(): void {", "  private async loadBundledKey(): Promise<void> {")
cut("  private async loadBundledKey(): Promise<void> {", "  private async runScript(): Promise<void> {")

text = text.replace(
    """    await this.loadSettings();
    await this.loadBundledKey();
    await this.loadMemory();
    await this.loadSkills();
    await this.loadRuns();
    await this.loadA11yList();
    await this.loadSchedules();""",
    """    await this.bootstrapSettings();
    await this.loadMemory();
    await this.loadSkills();
    await this.loadRuns();
    await this.loadSchedules();""",
)

bootstrap = """  /**
   * Applies the saved switches and configures the bundled development key.
   * The key is read from rawfile and never stored.
   */
  private async bootstrapSettings(): Promise<void> {
    try {
      const stored: StoredSettings = await SettingsStore.load(getContext(this) as Context);
      AgentService.get().setNetworkEnabled(stored.network);
      AgentService.get().setAutonomous(stored.autonomous);
      if (stored.bridgeUrl.length > 0 && stored.bridgeToken.length > 0) {
        AgentService.get().configureRemote(stored.bridgeUrl, stored.bridgeToken);
      }
    } catch (error) {
      // First run or an unreadable store: keep the defaults.
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const data = await context.resourceManager.getRawFileContent('deepseek.key');
      const key = buffer.from(data).toString('utf8').trim();
      if (key.length >= 10) {
        AgentService.get().configureModel(
          'deepseek',
          'https://api.deepseek.com/v1',
          key,
          'deepseek-v4-flash',
          6
        );
      }
    } catch (error) {
      // No bundled key: a normal first run.
    }
  }

"""
text = text.replace("  private async loadSchedules(): Promise<void> {", bootstrap + "  private async loadSchedules(): Promise<void> {", 1)

for block in [
    "  @State settingsPage: string = '';\n",
    "  @State networkEnabled: boolean = false;\n",
    "  @State autonomous: boolean = false;\n",
    "  @State provider: string = 'openai';\n",
    "  @State modelEndpoint: string = 'https://api.openai.com/v1';\n",
    "  @State modelName: string = 'gpt-4o-mini';\n",
    "  @State apiKey: string = '';\n",
    "  @State modelLabel: string = '';\n",
    "  @State a11yAvailable: boolean = false;\n",
    "  @State a11yInstalled: string = 'checking...';\n",
    "  @State accessibilityEnabled: boolean = false;\n",
    "  @State bridgeUrl: string = '';\n",
    "  @State bridgeToken: string = '';\n",
    "  @State bridgeStatus: string = 'not connected';\n",
    "import { accessibility } from '@kit.AccessibilityKit';\n",
]:
    text = text.replace(block, "")

p.write_text(text, encoding="utf-8", newline="\n")
print("lines:", len(text.splitlines()))
for token in ("settingsPage", "a11yAvailable", "modelLabel", "networkEnabled", "autonomous", "bridgeStatus", "SettingsHost", "AppAccessPage", "DeveloperPage", "clearRuns", "loadBundledKey", "loadA11yList"):
    if token in text:
        print("leftover:", token)
