from __future__ import annotations

import json
from pathlib import Path

from hopa_pc_agent.chat_store import ChatStore


def session(sid="s1", title="Hello", title_at=100, turns=None, deleted_at=0):
    return {
        "id": sid,
        "title": title,
        "titleAt": title_at,
        "deletedAt": deleted_at,
        "turns": turns or [],
    }


def turn(tid, text, at=100, role="user"):
    return {"id": tid, "role": role, "text": text, "at": at}


def test_merge_takes_everything_both_sides_know(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    store.merge([session(turns=[turn("t1", "hi")])])
    store.merge([session(turns=[turn("t2", "from the laptop", at=101)])])
    merged = store.snapshot()["sessions"][0]
    assert [item["id"] for item in merged["turns"]] == ["t1", "t2"]


def test_the_same_turn_twice_is_one_turn(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    payload = [session(turns=[turn("t1", "hi")])]
    store.merge(payload)
    store.merge(payload)
    assert len(store.snapshot()["sessions"][0]["turns"]) == 1
    assert store.rev == 1


def test_titles_are_last_writer_wins(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    store.merge([session(title="first", title_at=100)])
    store.merge([session(title="second", title_at=200)])
    store.merge([session(title="older", title_at=150)])
    assert store.snapshot()["sessions"][0]["title"] == "second"


def test_a_delete_is_a_tombstone(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    store.merge([session(turns=[turn("t1", "hi")])])
    store.merge([session(turns=[turn("t1", "hi")], deleted_at=300)])
    assert store.snapshot()["sessions"] == []
    # An older copy arriving afterwards must not bring it back.
    store.merge([session(turns=[turn("t1", "hi")])])
    assert store.snapshot()["sessions"] == []


def test_the_store_survives_a_restart(tmp_path):
    path = tmp_path / "chats.json"
    first = ChatStore(path)
    first.merge([session(turns=[turn("t1", "hi")])])
    rev = first.rev
    second = ChatStore(path)
    assert second.rev == rev
    assert second.snapshot()["sessions"][0]["title"] == "Hello"


def test_rev_grows_only_on_a_real_change(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    store.merge([session()])
    assert store.rev == 1
    store.merge([session()])
    assert store.rev == 1
    store.merge([session(turns=[turn("t1", "x")])])
    assert store.rev == 2


def test_sessions_are_newest_first(tmp_path):
    store = ChatStore(tmp_path / "chats.json")
    store.merge([
        session("old", turns=[turn("a", "x", at=10)]),
        session("new", turns=[turn("b", "y", at=90)]),
    ])
    assert [item["id"] for item in store.snapshot()["sessions"]] == ["new", "old"]


def test_a_hand_written_file_is_readable(tmp_path):
    path = tmp_path / "chats.json"
    path.write_text(json.dumps({
        "rev": 4,
        "sessions": {"s1": {"id": "s1", "title": "x", "titleAt": 1, "created": 1,
                             "updated": 2, "deletedAt": 0,
                             "turns": [turn("t1", "hello")]}},
    }), encoding="utf-8")
    store = ChatStore(path)
    assert store.rev == 4
    assert store.snapshot()["sessions"][0]["turns"][0]["text"] == "hello"
