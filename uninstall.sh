#!/usr/bin/env bash
set -euo pipefail

PANEL="$HOME/.config/quickshell/shell/modules/bar/barstyles/qsbar/panels/BatteryPanel.qml"
BACKUP="$PANEL.before-legion-battery"
HELPER="/usr/local/bin/ryoku-legion-battery"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -ne 0 ]] || die "Run as your normal user, not with sudo."
[[ -f "$PANEL" && ! -L "$PANEL" ]] \
    || die "Ryoku Battery panel is missing or is a symbolic link."
[[ -f "$BACKUP" && ! -L "$BACKUP" ]] \
    || die "Original Battery panel backup is missing or is a symbolic link."

if cmp -s -- "$PANEL" "$BACKUP"; then
    echo "Original Ryoku Battery panel is already restored."
    exit 0
fi

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PATCH="$PROJECT_DIR/patches/BatteryPanel.patch"

[[ -f "$PATCH" ]] || die "QML patch not found."
command -v git >/dev/null || die "Git is required."

TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/qml"
cp -p -- "$BACKUP" "$TMPDIR/qml/BatteryPanel.qml"

git -C "$TMPDIR" apply --check "$PATCH" \
    || die "Backup is incompatible with the project patch."

git -C "$TMPDIR" apply "$PATCH"

cmp -s "$PANEL" "$TMPDIR/qml/BatteryPanel.qml" \
    || die "Installed panel has additional changes. Refusing to overwrite."

echo "Restoring original Ryoku Battery panel..."
cp -p -- "$BACKUP" "$PANEL"

echo
echo "Original Battery panel restored."
echo "Backup retained at: $BACKUP"
echo "Run 'ryoku reload' to activate the original panel."
echo
echo "Charging helper retained at: $HELPER"
echo "It can be removed separately after confirming no other integration uses it."
