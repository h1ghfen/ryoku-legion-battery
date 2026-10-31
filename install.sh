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
[[ -f "$PANEL" && ! -L "$PANEL" ]] \
    || die "Ryoku BatteryPanel.qml is missing or is a symbolic link."
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
    if [[ ! -f "$BACKUP" || -L "$BACKUP" ]]; then
        die "Panel is patched but a valid original backup is missing."
    fi

    TMPDIR="$(mktemp -d)"
    trap 'rm -rf -- "$TMPDIR"' EXIT
    mkdir -p "$TMPDIR/qml"
    cp -- "$BACKUP" "$TMPDIR/qml/BatteryPanel.qml"

    git -C "$TMPDIR" apply --check "$PATCH" \
        || die "Original backup is incompatible with this patch."
    git -C "$TMPDIR" apply "$PATCH"

    cmp -s "$PANEL" "$TMPDIR/qml/BatteryPanel.qml" \
        || die "Installed panel contains unknown modifications."

    echo "Charging controls are already installed and verified."
    exit 0
fi

if [[ -e "$BACKUP" || -L "$BACKUP" ]]; then
    [[ -f "$BACKUP" && ! -L "$BACKUP" ]] \
        || die "Backup path is not a regular file: $BACKUP"

    BACKUP_CHECK="$(mktemp -d)"
    trap 'rm -rf -- "$BACKUP_CHECK"' EXIT

    mkdir -p "$BACKUP_CHECK/qml"
    cp -- "$BACKUP" "$BACKUP_CHECK/qml/BatteryPanel.qml"

    git -C "$BACKUP_CHECK" apply --check "$PATCH" \
        || die "Existing backup is incompatible with this patch."

    cmp -s -- "$BACKUP" "$PANEL" \
        || die "Existing backup differs from the current unpatched panel. Refusing to overwrite."

    rm -rf -- "$BACKUP_CHECK"
    trap - EXIT
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/qml" "$TMPDIR/original"
cp -p -- "$PANEL" "$TMPDIR/qml/BatteryPanel.qml"
cp -p -- "$PANEL" "$TMPDIR/original/BatteryPanel.qml"

git -C "$TMPDIR" apply --check "$PATCH" \
    || die "Installed Ryoku panel is incompatible with this patch."

git -C "$TMPDIR" apply "$PATCH"

if [[ ! -e "$BACKUP" ]]; then
    cp -p -- "$PANEL" "$BACKUP"
fi

if ! cp -- "$TMPDIR/qml/BatteryPanel.qml" "$PANEL"; then
    if cp -- "$TMPDIR/original/BatteryPanel.qml" "$PANEL"; then
        die "Panel installation failed; pre-installation panel restored."
    else
        die "Panel installation and rollback both failed. Manual recovery required."
    fi
fi

echo "Installing charging helper (administrator permission required)..."
if ! sudo install -o root -g root -m 755 \
    "$PROJECT_DIR/bin/ryoku-legion-battery" "$HELPER"; then
    if cp -- "$TMPDIR/original/BatteryPanel.qml" "$PANEL"; then
        die "Helper installation failed; pre-installation panel restored."
    else
        die "Helper installation failed and panel rollback failed. Manual recovery required."
    fi
fi

echo
echo "Installation complete."
echo "Backup: $BACKUP"
echo "Run 'ryoku reload' to activate the charging controls."
