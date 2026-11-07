from pathlib import Path

p = Path("apps/harmony/entry/src/main/ets/pages/Index.ets")
text = p.read_text(encoding="utf-8")
text = text.replace("    this.a11yAvailable = service.isA11yAvailable();\n", "")
text = text.replace("    this.modelLabel = service.getModelLabel();\n", "")
text = text.replace("      this.settingsPage = '';\n", "")
p.write_text(text, encoding="utf-8", newline="\n")
print("leftovers:", [t for t in ("settingsPage", "a11yAvailable", "modelLabel") if t in text], "lines:", len(text.splitlines()))
