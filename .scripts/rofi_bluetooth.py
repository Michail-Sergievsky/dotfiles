#!/usr/bin/env python3
"""Small Rofi front end for BlueZ power, paired devices and new pairing."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ADDRESS_RE = re.compile(r"^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}$")
DEVICE_RE = re.compile(r"^\s*Device\s+([0-9A-Fa-f:]{17})\s+(.+?)\s*$")


def clean(value: str) -> str:
    return " ".join(value.replace("\x00", "").split())


def run_bt(*args: str, timeout: int = 20) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bluetoothctl", *args], text=True, capture_output=True,
        timeout=timeout, check=False,
    )


def parse_devices(output: str) -> list[tuple[str, str]]:
    devices = {}
    for line in output.splitlines():
        match = DEVICE_RE.match(line)
        if match:
            address, name = match.groups()
            if ADDRESS_RE.fullmatch(address):
                devices[address.upper()] = clean(name) or address.upper()
    return sorted(devices.items(), key=lambda item: item[1].casefold())


def rofi_select(rows: list[str], prompt: str) -> int | None:
    if not rows:
        return None
    proc = subprocess.run(
        ["rofi", "-dmenu", "-i", "-format", "i", "-p", prompt],
        input="\n".join(rows) + "\n", text=True, capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        return None
    match = re.fullmatch(r"\s*(\d+)\s*", proc.stdout)
    return int(match.group(1)) if match else None


def notify(message: str, urgency: str = "normal") -> None:
    subprocess.run(
        ["notify-send", "--urgency", urgency, "Bluetooth", clean(message)],
        check=False, capture_output=True, text=True,
    )


def info(address: str) -> str:
    if not ADDRESS_RE.fullmatch(address):
        return ""
    result = run_bt("info", address)
    return result.stdout if result.returncode == 0 else ""


def property_yes(device_info: str, key: str) -> bool:
    return re.search(rf"^\s*{re.escape(key)}:\s*yes\s*$", device_info,
                     re.IGNORECASE | re.MULTILINE) is not None


def device_alias(device_info: str, fallback: str) -> str:
    match = re.search(r"^\s*Alias:\s*(.*?)\s*$", device_info,
                      re.IGNORECASE | re.MULTILINE)
    return clean(match.group(1)) if match and match.group(1).strip() else fallback


def controller_powered() -> bool:
    result = run_bt("show")
    return result.returncode == 0 and property_yes(result.stdout, "Powered")


def command_ok(*args: str) -> bool:
    result = run_bt(*args)
    output = clean(result.stdout + " " + result.stderr)
    if result.returncode != 0 or re.search(
            r"\b(Failed to|not available|No default controller|not ready|Invalid command)\b",
            output, re.IGNORECASE):
        notify(output or f"Command failed: {' '.join(args)}", "critical")
        return False
    notify(output or "Done")
    return True


def paired_devices() -> list[tuple[str, str, bool]]:
    result = run_bt("devices", "Paired")
    devices = []
    for address, name in parse_devices(result.stdout):
        device_info = info(address)
        devices.append((address, device_alias(device_info, name),
                        property_yes(device_info, "Connected")))
    return devices


def show_paired_menu() -> bool:
    devices = paired_devices()
    if not devices:
        notify("No paired devices found")
        return False
    rows = [f"{'●' if connected else '○'}  {name} · {address}"
            for address, name, connected in devices]
    rows.append("Back")
    selected = rofi_select(rows, "Paired Bluetooth devices")
    if selected == len(devices):
        return True
    if selected is None:
        return False
    if selected < 0 or selected >= len(devices):
        notify("Invalid Rofi selection", "critical")
        return False
    address, name, connected = devices[selected]
    verb = "disconnect" if connected else "connect"
    command_ok(verb, address)
    return False


def launch_pairing(address: str, name: str) -> None:
    """Open bluetoothctl in Kitty so the BlueZ agent can handle passkeys."""
    if not ADDRESS_RE.fullmatch(address):
        notify("Invalid Bluetooth address", "critical")
        return
    init_commands = f"agent KeyboardDisplay\ndefault-agent\npair {address}\n"
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", prefix="rofi-bluetooth-", suffix=".txt",
            delete=False,
        ) as temp_file:
            temp_file.write(init_commands)
            temp_path = Path(temp_file.name)
        subprocess.run(
            ["kitty", "--title", f"Pair Bluetooth: {clean(name)}", "-e",
             "bluetoothctl", "--agent", "KeyboardDisplay", "--init-script",
             str(temp_path)],
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        notify(f"Could not open pairing terminal: {exc}", "critical")
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def scan_for_new_device() -> bool:
    if not controller_powered():
        notify("Turn Bluetooth on before scanning")
        return False

    notify("Scanning for Bluetooth devices for 12 seconds…")
    try:
        scan = run_bt("--timeout", "12", "scan", "on", timeout=18)
    except subprocess.TimeoutExpired:
        notify("Bluetooth scan timed out", "critical")
        return False
    if scan.returncode != 0:
        notify(clean(scan.stderr or scan.stdout) or "Bluetooth scan failed", "critical")
        return False

    discovered = parse_devices(run_bt("devices").stdout)
    candidates = []
    for address, name in discovered:
        device_info = info(address)
        if not property_yes(device_info, "Paired"):
            candidates.append((address, device_alias(device_info, name)))
    if not candidates:
        notify("No unpaired devices found. Put the device in pairing mode and scan again.")
        return False

    rows = [f"{name} · {address}" for address, name in candidates]
    rows.append("Back")
    selected = rofi_select(rows, "Select device to pair")
    if selected == len(candidates):
        return True
    if selected is None:
        return False
    if selected < 0 or selected >= len(candidates):
        notify("Invalid Rofi selection", "critical")
        return False
    address, name = candidates[selected]
    launch_pairing(address, name)
    return False


def main() -> int:
    while True:
        try:
            powered = controller_powered()
        except (OSError, subprocess.SubprocessError) as exc:
            notify(f"Could not query Bluetooth: {exc}", "critical")
            return 1

        actions = ["Bluetooth: on" if powered else "Bluetooth: off",
                   "Paired devices", "Scan for new device", "Back to System"]
        selected = rofi_select(actions, "Bluetooth")
        if selected is None:
            return 0
        if selected == 0:
            return 0 if command_ok("power", "off" if powered else "on") else 1
        if selected == 1:
            if show_paired_menu():
                continue
            return 0
        if selected == 2:
            if scan_for_new_device():
                continue
            return 0
        if selected == 3:
            return subprocess.run(
                ["rofi", "-show", "blezz", "-modi", "blezz", "-auto-select",
                 "-matching", "normal", "-blezz-directory", "System"],
                check=False,
            ).returncode
        notify("Invalid Rofi selection", "critical")
        return 1


if __name__ == "__main__":
    sys.exit(main())
