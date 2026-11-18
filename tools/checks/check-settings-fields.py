#!/usr/bin/env python3
"""Every AppSettings field must be stored and read back.

A setting that exists only in the data class looks alive in the UI and silently
resets on the next reload; screenPath shipped exactly like that. This check reads
the field names from ``AppSettings`` and requires each one in both halves of the
DataStore repository: the ``AppSettings(...)`` read and the ``edit { }`` write.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = ROOT / "packages" / "stores" / "src" / "main" / "kotlin" / "com" / "hopa" / "stores" / "AppSettings.kt"
STORE = ROOT / "apps" / "android" / "data" / "src" / "main" / "kotlin" / "com" / "hopa" / "data" / "store" / "DataStoreSettingsRepository.kt"

FIELD = re.compile(r"^    val ([A-Za-z][A-Za-z0-9]*):")


def fields() -> list[str]:
    text = SETTINGS.read_text(encoding="utf-8")
    return FIELD.findall(text)


def check() -> list[str]:
    names = fields()
    store = STORE.read_text(encoding="utf-8")
    read_block = store[store.index("AppSettings(") : store.index("override suspend fun update")]
    write_block = store[store.index("context.settingsDataStore.edit") : store.index("override suspend fun modelKey")]
    problems: list[str] = []
    for name in names:
        if re.search(rf"\b{name}\s*=", read_block) is None:
            problems.append(f"{name}: never read from DataStore")
        if re.search(rf"\b{name}\b", write_block) is None:
            problems.append(f"{name}: never written to DataStore")
    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} setting storage problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
