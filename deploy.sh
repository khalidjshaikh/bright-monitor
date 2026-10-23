#!/usr/bin/env bash
#
# deploy.sh — build bright_monitor and install it to /usr/local/bin/bright_monitor.
#
# Usage:
#   ./deploy.sh                 # build and install
#   ./deploy.sh --no-build      # install the existing build, skip compiling
#   ./deploy.sh --prefix=/usr/local
#
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/bright_monitor.swift"
BUILD_DIR="$SCRIPT_DIR/.build"
BINARY="$BUILD_DIR/bright_monitor"

PREFIX="${PREFIX:-/usr/local}"
SKIP_BUILD=0

usage() {
    sed -n '3,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --no-build)
            SKIP_BUILD=1
            shift
            ;;
        --prefix)
            [[ $# -ge 2 ]] || { echo "❌ Missing value for --prefix" >&2; exit 1; }
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        *)
            echo "❌ Unknown argument: $1" >&2
            echo "   Run '$0 --help' for usage." >&2
            exit 1
            ;;
    esac
done

DEST_DIR="$PREFIX/bin"
DEST="$DEST_DIR/bright_monitor"

# ── Build ──────────────────────────────────────────────────
if [[ "$SKIP_BUILD" -eq 0 ]]; then
    [[ -f "$SOURCE" ]] || { echo "❌ Source not found: $SOURCE" >&2; exit 1; }

    echo "🔨 Building bright_monitor…"
    mkdir -p "$BUILD_DIR"
    swiftc -O "$SOURCE" -o "$BINARY"
    echo "   Built: $BINARY"
else
    [[ -x "$BINARY" ]] || { echo "❌ No existing build at $BINARY (drop --no-build)" >&2; exit 1; }
    echo "⏭  Skipping build, using: $BINARY"
fi

# ── Install ────────────────────────────────────────────────
SUDO=""
if ! mkdir -p "$DEST_DIR" 2>/dev/null; then
    echo "📁 Creating $DEST_DIR (needs sudo)…"
    sudo mkdir -p "$DEST_DIR"
    SUDO="sudo"
fi
[[ -w "$DEST_DIR" ]] || SUDO="sudo"

if [[ -n "$SUDO" ]]; then
    echo "🔐 Installing to $DEST (needs sudo)…"
else
    echo "📦 Installing to $DEST…"
fi
$SUDO install -m 0755 "$BINARY" "$DEST"

# ── Verify ─────────────────────────────────────────────────
if "$DEST" --help >/dev/null 2>&1; then
    echo "✅ Installed: $DEST"
else
    echo "❌ Install verification failed: $DEST --help returned an error" >&2
    exit 1
fi

if ! command -v bright >/dev/null 2>&1; then
    echo "⚠️  The 'bright' utility was not found on PATH; bright_monitor needs it to run."
fi

echo
echo "Run it with:  bright_monitor [-i <seconds>]"
