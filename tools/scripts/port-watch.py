"""Keep the hdc reverse port alive so the phone can reach the PC bridge.

The reverse mapping disappears whenever the hdc server restarts. This loop
re-adds it within a few seconds and logs to portwatch.log.
"""
import subprocess
import time
from pathlib import Path

HDC = r"C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
PHONE = "63Q0226113049275"
LOG = Path(r"C:\Users\m00645993\AppData\Local\Temp\opencode\portwatch.log")


def log(msg: str) -> None:
    stamp = time.strftime("%H:%M:%S")
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{stamp} {msg}\n")


def hdc(*args, timeout=20):
    return subprocess.run([HDC, "-t", PHONE, *args], capture_output=True,
                          text=True, timeout=timeout)


def main() -> None:
    log("watchdog start")
    misses = 0
    while True:
        try:
            out = hdc("fport", "ls").stdout or ""
            if "tcp:8766" in out and "Reverse" in out:
                if misses:
                    log("reverse ok again")
                misses = 0
            else:
                misses += 1
                res = hdc("rport", "tcp:8766", "tcp:8766")
                log(f"re-add #{misses}: {(res.stdout or '').strip()} {(res.stderr or '').strip()}")
        except Exception as exc:  # noqa: BLE001
            log(f"error: {type(exc).__name__}: {exc}")
        time.sleep(4)


main()
