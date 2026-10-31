# Ryoku Legion Battery

Native Lenovo Legion charging-mode controls for the Ryoku Linux Battery panel.

Switch between Conservation, Standard, and Rapid charging directly from the Ryoku top bar.

## Features

- Three charging modes with active-mode highlighting
- Automatic charging-mode detection
- Polkit authentication for charging-mode changes
- Compatibility checks before installation
- Idempotent installation with verification of existing patches
- Automatic backup and validation of the original Battery panel
- Panel rollback if installation fails
- Protection against symbolic links and unrelated panel modifications
- Idempotent uninstallation with backup preservation

## Charging modes

| Mode | Hardware value | Description |
|---|---|---|
| Conservation | `Long_Life` | Approximately 80% charging limit on supported Lenovo laptops |
| Standard | `Standard` | Normal charging |
| Rapid | `Fast` | Rapid charging |

Actual behavior depends on the laptop firmware.

## Compatibility

Tested on:

- Lenovo Legion 5 15IMH05H (81Y6)
- Ryoku Linux v1.0.6
- Arch Linux

Requires `/sys/class/power_supply/BAT0/charge_types` with `Fast`, `Standard`, and `Long_Life` support.

Other Lenovo models and Ryoku versions have not yet been verified.

## Requirements

Bash, Git, sudo, Polkit (`pkexec`), Ryoku Linux, and a compatible Lenovo charging interface.

## Installation

Clone the repository:

```bash
git clone git@github.com:h1ghfen/ryoku-legion-battery.git
cd ryoku-legion-battery
```

Install:

```bash
./install.sh
ryoku reload
```

Open the Battery panel in the Ryoku top bar.

Run the installer as your normal user, not with `sudo`. It requests administrator privileges when installing the charging helper.

The installer backs up the original panel before applying the patch.

Running `./install.sh` again is safe when the existing installation matches the original backup and project patch. In that case, the installer verifies the installation and exits without modifying files.

If the panel has unexpected modifications or the backup is incompatible, installation stops rather than overwriting those changes.

If panel installation or charging-helper installation fails, the installer attempts to restore the pre-installation panel. A rollback failure is reported explicitly.

The installer rejects symbolic links at the Battery panel path.

## Command-line usage

Check the current mode:

```bash
ryoku-legion-battery status
```

Change modes:

```bash
pkexec /usr/local/bin/ryoku-legion-battery conservation
pkexec /usr/local/bin/ryoku-legion-battery standard
pkexec /usr/local/bin/ryoku-legion-battery rapid
```

## Uninstallation

```bash
./uninstall.sh
ryoku reload
```

The uninstaller verifies that the installed panel exactly matches the original backup with the project patch applied before restoring it.

If the panel contains unrelated modifications, uninstallation stops without overwriting them.

Running `./uninstall.sh` again after a successful restoration is safe: it detects that the original panel is already restored and exits successfully.

The uninstaller rejects symbolic links at the panel and backup paths. It retains the original backup and charging helper; the helper is not automatically removed.

## Limitations

- Currently tested with Ryoku v1.0.6 only
- Requires the Lenovo `BAT0/charge_types` interface
- Ryoku updates may require an updated patch
- Uses a fixed backup filename
- Other hardware requires compatibility testing

## Project structure

```text
bin/ryoku-legion-battery    Charging-mode helper
patches/BatteryPanel.patch  Ryoku panel modifications
install.sh                  Installer
uninstall.sh                Uninstaller
README.md                   Documentation
```

## Upstream

An independent community integration for Ryoku Linux, not an official Ryoku project.

This repository distributes a patch rather than the complete upstream Battery panel source.

## Disclaimer

Charging-mode support depends on Lenovo firmware and kernel interfaces. Use at your own risk.
