from __future__ import annotations

from hopa_bridge.apps import parse_installed_apps
from hopa_bridge.device import Device


def test_bare_bundle_lines() -> None:
    apps = parse_installed_apps("com.huawei.hmos.settings\ncom.tencent.mm\ncom.huawei.hmos.clock\n")
    assert [app["bundle"] for app in apps] == [
        "com.huawei.hmos.clock",
        "com.huawei.hmos.settings",
        "com.tencent.mm",
    ]


def test_bundle_name_records() -> None:
    apps = parse_installed_apps(
        "BundleName: com.huawei.hmos.settings\nBundleName: com.huawei.hmos.calendar\n"
    )
    assert {app["bundle"] for app in apps} == {
        "com.huawei.hmos.settings",
        "com.huawei.hmos.calendar",
    }


def test_json_records() -> None:
    apps = parse_installed_apps('[{"bundleName": "com.huawei.hmos.notepad"}]')
    assert apps == [{"bundle": "com.huawei.hmos.notepad", "label": "com.huawei.hmos.notepad"}]


def test_noise_is_ignored() -> None:
    assert parse_installed_apps("error: no device\ncom.huawei.hmos.settings\n") == [
        {"bundle": "com.huawei.hmos.settings", "label": "com.huawei.hmos.settings"}
    ]


def test_duplicates_are_removed() -> None:
    apps = parse_installed_apps("com.tencent.mm\ncom.tencent.mm\n")
    assert len(apps) == 1


def test_device_apps_uses_bm_dump() -> None:
    class FakeHdc:
        def shell(self, command: str) -> str:
            assert command == "bm dump -a"
            return "com.huawei.hmos.settings\n"

    device = Device(hdc=FakeHdc())  # type: ignore[arg-type]
    assert device.apps()[0]["bundle"] == "com.huawei.hmos.settings"
