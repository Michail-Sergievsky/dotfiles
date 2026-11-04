#!/usr/bin/env python3
"""Rofi controls for mounting and safely removing USB storage."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from typing import Any


def clean_display(value: Any) -> str:
    """Keep device metadata on one harmless Rofi row."""
    text = str(value or "")
    return " ".join(text.replace("\x00", "").splitlines()).replace("\t", " ")


def mountpoints(node: dict[str, Any]) -> list[str]:
    raw = node.get("mountpoints") or []
    if isinstance(raw, str):
        raw = [raw]
    return [str(path) for path in raw if path]


def descendants(node: dict[str, Any]):
    for child in node.get("children") or []:
        yield child
        yield from descendants(child)


def usb_disks(data: dict[str, Any]) -> list[dict[str, Any]]:
    result = []
    for disk in data.get("blockdevices") or []:
        if disk.get("type") != "disk":
            continue
        transport = str(disk.get("tran") or "").lower()
        removable = disk.get("rm") in (True, 1, "1")
        if transport == "usb" or removable:
            if str(disk.get("path") or "").startswith("/dev/"):
                result.append(disk)
    return result


def volumes_for(data: dict[str, Any]) -> list[dict[str, Any]]:
    """Return filesystem-bearing USB nodes, retaining their physical drive."""
    volumes = []
    for disk in usb_disks(data):
        disk_path = str(disk["path"])
        model = clean_display(disk.get("model") or disk.get("name") or disk_path)
        nodes = [disk, *descendants(disk)]
        for node in nodes:
            path = str(node.get("path") or "")
            if not path.startswith("/dev/") or not node.get("fstype"):
                continue
            label = clean_display(node.get("label") or "(no label)")
            fstype = clean_display(node.get("fstype"))
            size = int(node.get("size") or 0)
            mounted = mountpoints(node)
            volumes.append({
                "path": path,
                "disk_path": disk_path,
                "disk_model": model,
                "label": label,
                "fstype": fstype,
                "size": size,
                "mountpoints": mounted,
            })
    return volumes


def display_size(size: int) -> str:
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    amount = float(size)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            return f"{amount:.0f} {unit}" if unit == "B" else f"{amount:.1f} {unit}"
        amount /= 1024
    return "?"


def rofi_index(rows: list[str], prompt: str) -> int | None:
    if not rows:
        return None
    proc = subprocess.run(
        ["rofi", "-dmenu", "-i", "-format", "i", "-p", prompt],
        input="\n".join(rows) + "\n",
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    match = re.fullmatch(r"\s*(\d+)\s*", proc.stdout)
    return int(match.group(1)) if match else None


def notify(title: str, message: str) -> None:
    subprocess.run(["notify-send", "-t", "5000", title, message], check=False)


def run_command(args: list[str]) -> tuple[bool, str]:
    proc = subprocess.run(args, text=True, capture_output=True, check=False)
    message = clean_display(proc.stdout or proc.stderr)
    return proc.returncode == 0, message


def read_inventory() -> dict[str, Any]:
    proc = subprocess.run(
        ["lsblk", "--json", "--tree", "--bytes", "-o",
         "PATH,NAME,TYPE,TRAN,RM,SIZE,LABEL,FSTYPE,MOUNTPOINTS,MODEL"],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError("Could not read block-device inventory")
    return json.loads(proc.stdout)


def safe_remove(volume: dict[str, Any], data: dict[str, Any]) -> tuple[bool, str]:
    """Unmount every mounted filesystem on this USB drive, then power it off."""
    disk = next(
        (item for item in usb_disks(data) if item.get("path") == volume["disk_path"]),
        None,
    )
    if disk is None:
        return False, "USB drive is no longer present"

    mounted_nodes = [disk, *descendants(disk)]
    mounted_paths = []
    for node in mounted_nodes:
        if mountpoints(node):
            path = str(node.get("path") or "")
            if path.startswith("/dev/"):
                mounted_paths.append(path)

    # Deepest block nodes first, without force; busy filesystems stop removal.
    for device in reversed(mounted_paths):
        ok, message = run_command(
            ["udisksctl", "unmount", "--block-device", device]
        )
        if not ok:
            return False, message or f"Could not unmount {device}; drive left powered"

    ok, message = run_command(
        ["udisksctl", "power-off", "--block-device", volume["disk_path"]]
    )
    if not ok:
        return False, message or "Unmounted, but the drive could not be powered off"
    return True, "USB drive unmounted and powered off; it is safe to disconnect"


def main() -> int:
    try:
        data = read_inventory()
        volumes = volumes_for(data)
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        notify("USB storage", str(exc))
        return 1

    if not volumes:
        notify("USB storage", "No mountable USB filesystems detected")
        return 0

    rows = []
    for volume in volumes:
        state = ", ".join(volume["mountpoints"]) if volume["mountpoints"] else "not mounted"
        rows.append(
            f"{volume['label']} · {volume['path']} · {volume['fstype']} · "
            f"{display_size(volume['size'])} · {state} · {volume['disk_model']}"
        )

    selected = rofi_index(rows, "USB storage")
    if selected is None:
        return 0
    if selected < 0 or selected >= len(volumes):
        notify("USB storage", "Rofi returned an invalid selection")
        return 1
    volume = volumes[selected]

    actions = ["Mount"] if not volume["mountpoints"] else ["Unmount"]
    actions.append("Safely remove drive")
    action_index = rofi_index(actions, volume["label"])
    if action_index is None:
        return 0
    if action_index < 0 or action_index >= len(actions):
        notify("USB storage", "Rofi returned an invalid action")
        return 1

    if action_index == 0 and actions[0] == "Mount":
        ok, message = run_command(
            ["udisksctl", "mount", "--block-device", volume["path"]]
        )
        notify("USB storage", message or ("Mounted" if ok else "Mount failed"))
        return 0 if ok else 1

    if action_index == 0 and actions[0] == "Unmount":
        ok, message = run_command(
            ["udisksctl", "unmount", "--block-device", volume["path"]]
        )
        notify("USB storage", message or ("Unmounted" if ok else "Unmount failed"))
        return 0 if ok else 1

    ok, message = safe_remove(volume, data)
    notify("USB storage", message)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
