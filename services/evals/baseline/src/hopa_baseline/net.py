"""URL and deep-link policy.

The executor checks this before any navigation or link action. The default is
HTTPS-only with any host (development); production passes an explicit host
allow-list from settings.
"""

from __future__ import annotations

from urllib.parse import urlsplit

from .errors import PolicyError

DANGEROUS_SCHEMES = {"javascript", "data", "file", "about", "blob"}


class UrlPolicy:
    def __init__(
        self,
        allowed_hosts: list[str] | set[str] | None = None,
        *,
        allow_http: bool = False,
    ) -> None:
        self.allowed_hosts = {
            host.lower().strip(".") for host in (allowed_hosts or []) if host.strip()
        }
        self.schemes = {"https"} | ({"http"} if allow_http else set())

    def check(self, url: str) -> str:
        if not url or not url.strip():
            raise PolicyError("empty URL")
        try:
            parts = urlsplit(url.strip())
        except ValueError as exc:
            raise PolicyError(f"invalid URL: {exc}") from exc

        scheme = parts.scheme.lower()
        if scheme in DANGEROUS_SCHEMES:
            raise PolicyError(f"scheme is not allowed: {scheme}")
        if scheme not in self.schemes:
            raise PolicyError(f"scheme must be https: {scheme or '(none)'}")
        if parts.username or parts.password:
            raise PolicyError("URLs with userinfo are not allowed")

        host = (parts.hostname or "").lower()
        if not host:
            raise PolicyError("URL has no host")
        if self.allowed_hosts and not self._host_allowed(host):
            raise PolicyError(f"host is not on the allow-list: {host}")
        return url.strip()

    def _host_allowed(self, host: str) -> bool:
        for allowed in self.allowed_hosts:
            if host == allowed or host.endswith("." + allowed):
                return True
        return False
