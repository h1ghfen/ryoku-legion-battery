#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PANEL_DIR="$HOME/.config/quickshell/shell/modules/bar/barstyles/qsbar/panels"
PANEL="$PANEL_DIR/BatteryPanel.qml"
BATTERY="/sys/class/power_supply/BAT0/charge_types"
HELPER="/usr/local/bin/ryoku-legion-battery"
BACKUP="$PANEL.before-legion-battery"
PATCH="$PROJECT_DIR/patches/BatteryPanel.patch"

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -ne 0 ]] || die "Run as your normal user, not with sudo."
[[ -f "$PANEL" ]] || die "Ryoku BatteryPanel.qml not found."
[[ -r "$BATTERY" ]] || die "Lenovo charging interface not found."
[[ -f "$PATCH" ]] || die "QML patch not found."
[[ -f "$PROJECT_DIR/bin/ryoku-legion-battery" ]] || die "Helper not found."

available_modes="$(tr '[]' '  ' < "$BATTERY")"

for mode in Fast Standard Long_Life; do
    [[ " $available_modes " == *" $mode "* ]] \
        || die "Unsupported charging mode: $mode"
done

command -v git >/dev/null || die "Git is required."
command -v pkexec >/dev/null || die "Polkit (pkexec) is required."
command -v sudo >/dev/null || die "sudo is required."

if grep -q 'id: chargeModeRead' "$PANEL"; then
    die "Charging controls are already installed."
fi

if [[ -e "$BACKUP" ]]; then
    [[ -f "$BACKUP" && ! -L "$BACKUP" ]] \
        || die "Backup path is not a regular file: $BACKUP"
    cmp -s -- "$PANEL" "$BACKUP" \
        || die "Existing backup differs from the current panel. Refusing to overwrite."
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/qml"
cp -p -- "$PANEL" "$TMPDIR/qml/BatteryPanel.qml"

git -C "$TMPDIR" apply --check "$PATCH" \
    || die "Installed Ryoku panel is incompatible with this patch."

git -C "$TMPDIR" apply "$PATCH"

echo "Installing charging helper (administrator permission required)..."
sudo install -o root -g root -m 755 \
    "$PROJECT_DIR/bin/ryoku-legion-battery" "$HELPER"

if [[ ! -e "$BACKUP" ]]; then
    cp -p -- "$PANEL" "$BACKUP"
fi

if ! cp -- "$TMPDIR/qml/BatteryPanel.qml" "$PANEL"; then
    cp -- "$BACKUP" "$PANEL"
    die "Panel installation failed; original restored."
fi

echo
echo "Installation complete."
echo "Backup: $BACKUP"
echo "Run 'ryoku reload' to activate the charging controls."
