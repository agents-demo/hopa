"""Images the shells share, stored once on the PC.

A laptop cannot open a path inside the phone's sandbox, so a run screenshot is
uploaded here and downloaded by whichever shell has to show it. Content is
addressed by its hash, so the same frame uploaded twice costs one file.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import threading
from pathlib import Path

MAX_IMAGE_BYTES = 4 * 1024 * 1024
FALLBACK_TYPE = "image/jpeg"


class ImageStore:
    def __init__(self, root: Path | None = None) -> None:
        self.root = root if root is not None else Path.home() / ".hopa" / "images"
        self.root.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()

    def put(self, mime: str, data: str) -> dict[str, object]:
        try:
            raw = base64.b64decode(data, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ValueError("data is not base64") from exc
        if not raw:
            raise ValueError("empty image")
        if len(raw) > MAX_IMAGE_BYTES:
            raise ValueError("image is larger than 4 MB")
        kind = mime if mime.startswith("image/") else FALLBACK_TYPE
        image_id = hashlib.sha256(raw).hexdigest()[:24]
        path = self.root / image_id
        with self.lock:
            if not path.exists():
                path.write_bytes(raw)
                (self.root / f"{image_id}.type").write_text(kind, encoding="utf-8")
        return {"id": image_id, "mime": kind, "bytes": len(raw)}

    def get(self, image_id: str) -> tuple[bytes, str] | None:
        if not image_id or "/" in image_id or ".." in image_id:
            return None
        path = self.root / image_id
        if not path.exists():
            return None
        kind = FALLBACK_TYPE
        kind_path = self.root / f"{image_id}.type"
        if kind_path.exists():
            kind = kind_path.read_text(encoding="utf-8").strip() or FALLBACK_TYPE
        return path.read_bytes(), kind

    def has(self, image_id: str) -> bool:
        if not image_id or "/" in image_id or ".." in image_id:
            return False
        return (self.root / image_id).exists()
