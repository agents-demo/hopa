from __future__ import annotations

from hopa_pc_agent.layout import parse_layout

SAMPLE = {
    "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
    "children": [
        {
            "attributes": {
                "type": "Button",
                "text": "Wi-Fi",
                "bounds": "[0,100][540,200]",
                "clickable": "true",
                "enabled": "true",
            },
            "children": [],
        },
        {
            "attributes": {
                "type": "Text",
                "text": "Bluetooth",
                "bounds": "[0,300][540,400]",
                "clickable": "false",
            },
            "children": [],
        },
    ],
}


def test_parse_and_walk() -> None:
    layout = parse_layout(SAMPLE)
    assert len(list(layout.walk())) == 3


def test_find_by_text_is_case_insensitive() -> None:
    layout = parse_layout(SAMPLE)
    matches = layout.find_by_text("wi-fi")
    assert len(matches) == 1
    assert matches[0].text == "Wi-Fi"
    assert matches[0].clickable is True


def test_bounds_and_center() -> None:
    layout = parse_layout(SAMPLE)
    node = layout.find_by_text("Wi-Fi")[0]
    assert node.bounds == (0, 100, 540, 200)
    assert node.center == (270, 150)


def test_exact_match() -> None:
    layout = parse_layout(SAMPLE)
    assert layout.find_by_text("Wi", exact=True) == []
    assert len(layout.find_by_text("Wi-Fi", exact=True)) == 1


def test_handles_list_root() -> None:
    layout = parse_layout([SAMPLE, SAMPLE])
    assert len(layout.roots) == 2
    assert len(layout.find_by_text("Bluetooth")) == 2


def test_handles_window_mapping() -> None:
    layout = parse_layout({"0": SAMPLE, "1": SAMPLE})
    assert len(layout.roots) == 2


def test_missing_bounds() -> None:
    layout = parse_layout({"attributes": {"text": "no box"}})
    node = layout.find_by_text("no box")[0]
    assert node.bounds is None
    assert node.center is None


def test_to_dict_round_trips_shape() -> None:
    layout = parse_layout(SAMPLE)
    payload = layout.to_dict()
    assert "roots" in payload
    assert payload["roots"][0]["attributes"]["type"] == "Root"
