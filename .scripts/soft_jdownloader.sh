#!/usr/bin/env bash
set -e

export _JAVA_AWT_WM_NONREPARENTING=1

JD_DIR="$HOME/.jd"
JAVA="/usr/lib/jvm/java-8-openjdk/jre/bin/java"

if [[ ! -x "$JAVA" ]]; then
    echo "Error: Java 8 not found: $JAVA" >&2
    exit 1
fi

if [[ ! -f "$JD_DIR/JDownloader.jar" ]]; then
    echo "Error: JDownloader.jar not found: $JD_DIR/JDownloader.jar" >&2
    exit 1
fi

cd "$JD_DIR"
exec "$JAVA" -jar JDownloader.jar "$@"
