#!/usr/bin/env python3

import json
import shutil
import subprocess
import sys
from pathlib import Path


def die(msg, code=1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def human_size(num):
    try:
        num = float(num)
    except Exception:
        return "?"

    units = ["B", "KiB", "MiB", "GiB", "TiB"]

    for unit in units:
        if abs(num) < 1024.0:
            if unit == "B":
                return f"{int(num)} {unit}"
            return f"{num:.2f} {unit}"
        num /= 1024.0

    return f"{num:.2f} PiB"


def human_duration_ns(ns):
    if ns is None:
        return "?"

    try:
        seconds = int(ns) / 1_000_000_000
    except Exception:
        return "?"

    h = int(seconds) // 3600
    m = (int(seconds) % 3600) // 60
    s = int(seconds) % 60

    if h:
        return f"{h} h {m:02d} min {s:02d} sec"
    if m:
        return f"{m} min {s:02d} sec"

    return f"{s} sec"


def human_bitrate(size_bytes, duration_ns):
    if not size_bytes or not duration_ns:
        return "?"

    try:
        seconds = int(duration_ns) / 1_000_000_000
        bps = int(size_bytes) * 8 / seconds
    except Exception:
        return "?"

    if bps >= 1_000_000:
        return f"{bps / 1_000_000:.2f} Mb/s"
    if bps >= 1_000:
        return f"{bps / 1_000:.2f} kb/s"

    return f"{bps:.0f} b/s"


def get_json(path):
    if shutil.which("mkvmerge") is None:
        die("mkvmerge not found. Install mkvtoolnix-cli.")

    p = subprocess.run(
        ["mkvmerge", "-J", str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    if p.returncode != 0:
        die(p.stderr.strip() or "mkvmerge failed")

    return json.loads(p.stdout)


def yesno(value):
    return "yes" if value else "no"


def lang(props):
    return props.get("language_ietf") or props.get("language") or "und"


def codec(track):
    return track.get("codec") or track.get("properties", {}).get("codec_id") or "?"


def header(title):
    print()
    print(title)
    print("-" * len(title))


def kv(key, value, indent=2):
    print(" " * indent + f"{key:<15}: {value}")


def fps_from_default_duration(value):
    if not value:
        return ""

    # mkvmerge can return integer nanoseconds.
    if isinstance(value, int):
        if value > 0:
            return f"{1_000_000_000 / value:.3f} FPS"
        return ""

    # Or string like "00:00:00.041708333".
    if isinstance(value, str):
        if value.startswith("00:00:00."):
            try:
                frac = value.split(".")[1]
                ns = int(frac.ljust(9, "0")[:9])
                if ns > 0:
                    return f"{1_000_000_000 / ns:.3f} FPS"
            except Exception:
                return value

        return value

    return ""


def compact_flags(props):
    return f"lang={lang(props)} | def={yesno(props.get('default_track'))} | forced={yesno(props.get('forced_track'))}"


def print_video(track, n):
    props = track.get("properties", {})

    pixel = props.get("pixel_dimensions") or "?"
    display = props.get("display_dimensions")
    fps = fps_from_default_duration(props.get("default_duration"))

    parts = [
        f"V{n}: {codec(track)}",
        pixel,
    ]

    if display and display != pixel:
        parts.append(f"display={display}")

    if fps:
        parts.append(fps)

    parts.append(compact_flags(props))

    print(" | ".join(parts))

    name = props.get("track_name")
    if name:
        print(f"    Name: {name}")


def print_audio(track, n):
    props = track.get("properties", {})

    channels = props.get("audio_channels")
    channel_part = f"{channels} ch" if channels else "? ch"

    parts = [
        f"A{n}: {codec(track)}",
        channel_part,
        compact_flags(props),
    ]

    print(" | ".join(parts))

    name = props.get("track_name")
    if name:
        print(f"    Name: {name}")


def print_sub(track, n):
    props = track.get("properties", {})

    parts = [
        f"S{n}: {codec(track)}",
        compact_flags(props),
    ]

    print(" | ".join(parts))

    name = props.get("track_name")
    if name:
        print(f"    Name: {name}")


def print_attachment(att, n):
    name = att.get("file_name") or "?"
    ctype = att.get("content_type") or "?"
    size = att.get("size")

    if size is not None:
        print(f"{n}: {name} | {ctype} | {human_size(size)}")
    else:
        print(f"{n}: {name} | {ctype}")


def collect_chapters(obj):
    result = []

    def walk(x):
        if isinstance(x, dict):
            name = x.get("name") or x.get("string")
            start = x.get("start") or x.get("start_timestamp")

            if name or start:
                result.append((start, name))

            for value in x.values():
                walk(value)

        elif isinstance(x, list):
            for item in x:
                walk(item)

    walk(obj)
    return result


def main():
    if len(sys.argv) != 2:
        die("usage: mkvscan.py FILE.mkv")

    path = Path(sys.argv[1])

    if not path.is_file():
        die(f"not a file: {path}")

    data = get_json(path)

    container = data.get("container", {})
    cprops = container.get("properties", {})

    tracks = data.get("tracks", [])
    attachments = data.get("attachments", [])
    chapters = data.get("chapters", [])

    size = path.stat().st_size
    duration_ns = cprops.get("duration")

    print(f"File: {path.name}")

    header("General")
    kv("File size", human_size(size))
    kv("Duration", human_duration_ns(duration_ns))
    kv("Bitrate", human_bitrate(size, duration_ns))

    title = cprops.get("title")
    date_utc = cprops.get("date_utc")
    muxing_app = cprops.get("muxing_application")
    writing_app = cprops.get("writing_application")

    if title:
        kv("Title", title)
    if date_utc:
        kv("Date UTC", date_utc)
    if muxing_app:
        kv("Muxing app", muxing_app)
    if writing_app:
        kv("Writing app", writing_app)

    video_tracks = [t for t in tracks if t.get("type") == "video"]
    audio_tracks = [t for t in tracks if t.get("type") == "audio"]
    subtitle_tracks = [t for t in tracks if t.get("type") == "subtitles"]

    header(f"Video ({len(video_tracks)})")
    if video_tracks:
        for i, track in enumerate(video_tracks, start=1):
            print_video(track, i)
    else:
        print("none")

    header(f"Audio ({len(audio_tracks)})")
    if audio_tracks:
        for i, track in enumerate(audio_tracks, start=1):
            print_audio(track, i)
    else:
        print("none")

    header(f"Subtitles ({len(subtitle_tracks)})")
    if subtitle_tracks:
        for i, track in enumerate(subtitle_tracks, start=1):
            print_sub(track, i)
    else:
        print("none")

    header(f"Attachments ({len(attachments)})")
    if attachments:
        for i, att in enumerate(attachments, start=1):
            print_attachment(att, i)
    else:
        print("none")

    header(f"Chapters ({len(chapters)})")
    if chapters:
        entries = collect_chapters(chapters)
        if entries:
            for i, (start, name) in enumerate(entries[:20], start=1):
                start = start or "?"
                name = name or ""
                print(f"{i:02d}: {start} {name}".rstrip())

            if len(entries) > 20:
                print(f"... {len(entries) - 20} more chapters")
        else:
            print("present")
    else:
        print("none")


if __name__ == "__main__":
    main()
