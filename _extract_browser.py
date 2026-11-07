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
    "import { AppsPage } from './apps/AppsPage';",
    "import { AppsPage } from './apps/AppsPage';\nimport { BrowserPage } from './browser/BrowserPage';",
)
text = text.replace(
    "    } else if (this.activePage === 'browser') {\n      this.WebPage()",
    "    } else if (this.activePage === 'browser') {\n      BrowserPage()",
)
text = text.replace(
    """            onOpenSite: (url: string) => {
              this.address = url;
              this.activePage = 'browser';
              setTimeout(() => {
                this.openAddress();
              }, 500);
            }""",
    """            onOpenSite: (url: string) => {
              AgentService.get().browser.requestUrl(url);
              this.activePage = 'browser';
            }""",
)

cut("  @Builder\n  WebPage() {", "  @Builder\n  MoreToolsPage() {")
cut("  private async runScript(): Promise<void> {", "  @Builder\n  ChatPage() {")

for block in [
    "  @State address: string = 'https://example.com';\n",
    "  @State pageUrl: string = '';\n",
    "  @State script: string = '';\n",
    "  @State scriptOutput: string = '';\n",
    "  private webController: webview.WebviewController = new webview.WebviewController();\n",
    "  private sandboxController: webview.WebviewController = new webview.WebviewController();\n",
    "import { webview } from '@kit.ArkWeb';\n",
    "import { JsSandboxBridge } from '../services/JsSandboxBridge';\n",
]:
    text = text.replace(block, "")

p.write_text(text, encoding="utf-8", newline="\n")
print("lines:", len(text.splitlines()))
for token in ("WebPage", "address", "pageUrl", "scriptOutput", "webController", "runScript", "openAddress", "JsSandboxBridge"):
    if token in text:
        print("leftover:", token)
