from __future__ import annotations

import pytest

from hopa_agent.actions import Action
from hopa_agent.errors import PolicyError
from hopa_agent.executor import DeviceExecutor
from hopa_agent.net import UrlPolicy


def test_https_is_allowed():
    assert UrlPolicy().check("https://example.com/path") == "https://example.com/path"


def test_http_is_rejected():
    with pytest.raises(PolicyError):
        UrlPolicy().check("http://example.com")


def test_dangerous_schemes_are_rejected():
    for url in ("javascript:alert(1)", "file:///etc/passwd", "data:text/html,x"):
        with pytest.raises(PolicyError):
            UrlPolicy().check(url)


def test_userinfo_is_rejected():
    with pytest.raises(PolicyError):
        UrlPolicy().check("https://user:pass@example.com")


def test_allow_list_allows_subdomains():
    policy = UrlPolicy(["example.com"])
    assert policy.check("https://www.example.com") == "https://www.example.com"
    with pytest.raises(PolicyError):
        policy.check("https://evil-example.com")


def test_executor_checks_urls(settings_device):
    outcome = DeviceExecutor(settings_device).execute(
        Action.from_dict({"kind": "web.navigate", "url": "javascript:alert(1)"})
    )
    assert outcome.executed is False
    assert "scheme" in (outcome.error or "")


def test_exfiltration_to_an_unapproved_host_is_blocked(settings_device):
    executor = DeviceExecutor(settings_device, url_policy=UrlPolicy(["good.example"]))
    outcome = executor.execute(
        Action.from_dict({"kind": "web.navigate", "url": "https://evil.example/?data=secret"})
    )
    assert outcome.executed is False
    assert "allow-list" in (outcome.error or "")
