#!/usr/bin/env bash

set -u
set -o pipefail

DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

find . -type f -iname '*.mkv' -print0 |
python3 - "$DRY_RUN" 3<&0 <<'PY'
import os
import re
import shlex
import subprocess
import sys

dry_run = sys.argv[1] == "1"

def normalize_name(path):
    dirname = os.path.dirname(path)
    basename = os.path.basename(path)
    stem, ext = os.path.splitext(basename)

    name = stem

    # Remove duplicate suffixes from copied files: " (1)", " (2)"
    name = re.sub(r"\s+\(\d+\)$", "", name)

    # Normalize separators for easier matching
    work = re.sub(r"[._ ]+", ".", name)

    # Resolution
    res_match = re.search(r"(?i)(720p|1080p)", work)
    resolution = res_match.group(1).lower() if res_match else "1080p"

    # Source: default BD if unknown
    source = "BD"

    if re.search(r"(?i)(WEB[-_. ]?DL|WEBRip|WEB)", work):
        source = "WEB"
    elif re.search(r"(?i)(BDRemux|BD.Remux|BD Remux|BluRay|Bluray|Blu-ray|BDRip|Bdrip-avc|REMUX|BD)", work):
        source = "BD"

    clean = work

    remove_patterns = [
        # resolution
        r"(?i)720p",
        r"(?i)1080p",

        # BD source tags
        r"(?i)BDRemux",
        r"(?i)BD.Remux",
        r"(?i)BD Remux",
        r"(?i)BluRay",
        r"(?i)Bluray",
        r"(?i)Blu-ray",
        r"(?i)BDRip",
        r"(?i)Bdrip-avc",
        r"(?i)REMUX",
        r"(?i)\bBD\b",

        # WEB source tags
        r"(?i)WEB[-_. ]?DL",
        r"(?i)WEBRip",
        r"(?i)\bWEB\b",

        # codec tags
        r"(?i)x264",
        r"(?i)h264",
        r"(?i)AVC",
        r"(?i)x265",
        r"(?i)h265",
        r"(?i)HEVC",

        # audio tags
        r"(?i)FLAC",
        r"(?i)DTS",
        r"(?i)AC3",
        r"(?i)AAC",
        r"(?i)TrueHD",
        r"(?i)Atmos",
        r"(?i)OPUS",

        # language/subtitle/platform/release-group noise
        r"(?i)Rus",
        r"(?i)Eng",
        r"(?i)Chi",
        r"(?i)KOREAN",
        r"(?i)2xSub",
        r"(?i)MultiSub",
        r"(?i)Multi.Sub",
        r"(?i)AMZN",
        r"(?i)NF",
        r"(?i)iQIYI",

        # release group at end: -CHD, -DON, etc.
        r"(?i)-[A-Za-z0-9]+$",
    ]

    for pat in remove_patterns:
        clean = re.sub(pat, "", clean)

    # Clean leftover separators
    clean = re.sub(r"[._ ]+", ".", clean)
    clean = re.sub(r"\.+", ".", clean)
    clean = clean.strip(". ")

    if not clean:
        clean = stem.strip(". ")

    new_basename = f"{clean}.{source}.{resolution}.x265{ext}"
    return os.path.join(dirname, new_basename)


changed = 0
skipped = 0
failed = 0

for raw in os.fdopen(3, "rb").read().split(b"\0"):
    if not raw:
        continue

    old = raw.decode("utf-8", errors="surrogateescape")
    new = normalize_name(old)

    if old == new:
        skipped += 1
        continue

    print("------------------------------------------------------------")
    print(f"OLD: {old}")
    print(f"NEW: {new}")

    if dry_run:
        print("DRY-RUN: not renamed")
        changed += 1
        continue

    try:
        subprocess.run(["mv", "-i", "--", old, new], check=True)
        changed += 1
    except subprocess.CalledProcessError as e:
        print(f"FAILED: mv returned {e.returncode}", file=sys.stderr)
        failed += 1

print("------------------------------------------------------------")
print(f"Changed: {changed}")
print(f"Skipped: {skipped}")
print(f"Failed:  {failed}")

if failed:
    sys.exit(1)
PY
