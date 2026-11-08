from __future__ import annotations

import json
from pathlib import Path

import pytest

from hopa_agent.actions import Action
from hopa_agent.errors import ModelError, SchemaError
from hopa_agent.models import (
    OpenAIClient,
    StubModelClient,
    api_key_from_env,
    load_steps,
)


def _response(content: str, tokens: int = 7) -> dict:
    return {
        "choices": [{"message": {"content": content}}],
        "usage": {"total_tokens": tokens},
    }


def test_openai_parses_an_action(settings_observation):
    client = OpenAIClient(
        api_key="k",
        model="m",
        transport=lambda payload: _response(
            '{"action":{"kind":"ui.tap","ref":"e1"},"say":"ok","done":false,"needUser":false}'
        ),
    )
    decision = client.decide("goal", settings_observation, [], 0)
    assert decision.action is not None
    assert decision.action.ref == "e1"
    assert decision.tokens == 7


def test_openai_repairs_malformed_json_once(settings_observation):
    calls: list[dict] = []

    def transport(payload: dict) -> dict:
        calls.append(payload)
        if len(calls) == 1:
            return _response("this is not json")
        return _response('{"action":null,"say":"fixed","done":true,"needUser":false}')

    client = OpenAIClient(api_key="k", model="m", transport=transport)
    decision = client.decide("goal", settings_observation, [], 0)
    assert decision.done is True
    assert decision.say == "fixed"
    assert len(calls) == 2


def test_openai_retries_then_fails(settings_observation):
    client = OpenAIClient(
        api_key="k",
        model="m",
        max_retries=0,
        transport=lambda payload: (_ for _ in ()).throw(RuntimeError("boom")),
    )
    with pytest.raises(ModelError):
        client.decide("goal", settings_observation, [], 0)


def test_openai_rejects_no_choices(settings_observation):
    client = OpenAIClient(
        api_key="k", model="m", max_retries=0, transport=lambda payload: {"choices": []}
    )
    with pytest.raises(ModelError):
        client.decide("goal", settings_observation, [], 0)


def test_prompt_contains_the_screen(settings_observation):
    client = OpenAIClient(api_key="k", model="m", transport=lambda payload: _response("{}"))
    messages = client._messages("tap Bluetooth", settings_observation, [], 0)
    assert "Bluetooth" in messages[1]["content"]
    assert "untrusted" in messages[0]["content"]


def test_parse_options():
    client = OpenAIClient(api_key="k", model="m", transport=lambda payload: _response("{}"))
    decision = client._parse(
        '{"action":null,"say":"choose","done":false,"needUser":true,"options":["A","B"]}'
    )
    assert decision.options == ["A", "B"]


def test_stub_replays_then_finishes(settings_observation):
    model = StubModelClient([{"kind": "ui.tap", "ref": "e1"}, {"kind": "ui.back"}])
    first = model.decide("g", settings_observation, [], 0)
    second = model.decide("g", settings_observation, [], 1)
    third = model.decide("g", settings_observation, [], 2)
    assert first.action is not None
    assert second.action is not None
    assert third.done is True


def test_stub_rejects_non_list():
    with pytest.raises(SchemaError):
        StubModelClient.from_json({"kind": "ui.tap"})


def test_load_steps(tmp_path: Path, settings_observation):
    path = tmp_path / "steps.json"
    path.write_text(json.dumps([{"kind": "ui.tap", "ref": "e1"}]), encoding="utf-8")
    model = load_steps(str(path))
    assert model.decide("g", settings_observation, [], 0).action == Action.from_dict(
        {"kind": "ui.tap", "ref": "e1"}
    )


def test_api_key_from_env(monkeypatch):
    monkeypatch.setenv("HOPA_API_KEY", "secret")
    assert api_key_from_env() == "secret"
