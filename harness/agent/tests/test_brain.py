from __future__ import annotations

import pytest

from hopa_agent.brain import BrainClient, BrainError, BrainFirstModel, installed_bundles
from hopa_agent.models import StubModelClient


def _route(action: dict | None, *, say: str = "", need_user: bool = False, options=None) -> dict:
    return {
        "action": action,
        "say": say,
        "done": False,
        "needUser": need_user,
        "options": options or [],
    }


def test_route_parses_a_launch_action():
    client = BrainClient(
        "http://brain",
        transport=lambda payload: _route(
            {"kind": "ui.launch", "app": "com.tencent.wechat"}, say="Opening WeChat."
        ),
    )
    route = client.route("open wechat", ["com.tencent.wechat"])
    assert route.action is not None
    assert route.action.kind == "ui.launch"
    assert route.action.app == "com.tencent.wechat"
    assert route.say == "Opening WeChat."
    assert route.need_user is False


def test_route_sends_bundle_and_label():
    seen: list[dict] = []

    def transport(payload: dict) -> dict:
        seen.append(payload)
        return _route(None, need_user=True)

    client = BrainClient("http://brain", transport=transport)
    client.route("open settings", ["com.huawei.hmos.settings"])
    assert seen[0]["settings"]["installed"] == [
        {"bundle": "com.huawei.hmos.settings", "label": "com.huawei.hmos.settings"}
    ]


def test_route_returns_need_user_and_options():
    client = BrainClient(
        "http://brain",
        transport=lambda payload: _route(
            None, say="Which one?", need_user=True, options=["A", "B"]
        ),
    )
    route = client.route("open chat")
    assert route.action is None
    assert route.need_user is True
    assert route.options == ["A", "B"]


def test_route_wraps_transport_failure():
    def transport(payload: dict) -> dict:
        raise OSError("connection refused")

    client = BrainClient("http://brain", transport=transport)
    with pytest.raises(BrainError):
        client.route("open settings")


def test_route_rejects_a_bad_action():
    client = BrainClient(
        "http://brain",
        transport=lambda payload: _route({"kind": "ui.launch"}),
    )
    with pytest.raises(BrainError):
        client.route("open settings")


def test_brain_first_uses_the_brain_at_step_zero(settings_observation):
    client = BrainClient(
        "http://brain",
        transport=lambda payload: _route({"kind": "ui.launch", "app": "com.huawei.hmos.settings"}),
    )
    fallback = StubModelClient([])
    model = BrainFirstModel(client, ["com.huawei.hmos.settings"], fallback)
    decision = model.decide("open settings", settings_observation, [], 0)
    assert decision.action is not None
    assert decision.action.kind == "ui.launch"


def test_brain_first_delegates_after_step_zero(settings_observation):
    client = BrainClient("http://brain", transport=lambda payload: _route(None, say="x"))
    fallback = StubModelClient([{"kind": "ui.tap", "ref": "e1"}])
    model = BrainFirstModel(client, [], fallback)
    decision = model.decide("open settings", settings_observation, [], 1)
    assert decision.action is not None
    assert decision.action.kind == "ui.tap"


def test_brain_first_falls_back_when_the_brain_is_down(settings_observation):
    def transport(payload: dict) -> dict:
        raise OSError("connection refused")

    model = BrainFirstModel(
        BrainClient("http://brain", transport=transport),
        [],
        StubModelClient([{"kind": "ui.tap", "ref": "e1"}]),
    )
    decision = model.decide("open settings", settings_observation, [], 0)
    assert decision.action is not None
    assert decision.action.kind == "ui.tap"
    assert "connection refused" in model.last_brain_error


def test_brain_need_user_stops_before_the_model(settings_observation):
    client = BrainClient("http://brain", transport=lambda payload: _route(None, need_user=True))
    fallback = StubModelClient([{"kind": "ui.tap", "ref": "e1"}])
    model = BrainFirstModel(client, [], fallback)
    decision = model.decide("who?", settings_observation, [], 0)
    assert decision.action is None
    assert decision.need_user is True


def test_installed_bundles_is_best_effort():
    class Device:
        def apps(self):
            return [{"bundle": "a.b", "label": "A"}]

    assert installed_bundles(Device()) == ["a.b"]

    class Broken:
        def apps(self):
            raise RuntimeError("no device")

    assert installed_bundles(Broken()) == []
