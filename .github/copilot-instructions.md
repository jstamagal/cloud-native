# Cloud-Native Desktop Kit - Copilot Instructions

## Project Overview
Bash toolkit for building a "cloud-native desktop" on ultra-minimal hosts (Fedora CoreOS, bootc). Apps run in **distrobox containers**, persistent services use **podman + systemd quadlets**. Everything is rootless by default.

## Architecture
- **`bin/`** - User-facing CLI scripts (source `lib/common.sh`)
- **`lib/common.sh`** - Shared helpers: `log`, `die`, `have`, `sudo_maybe`, `detect_pkg_manager`, `pkg_is_installed`, `pkg_install_if_missing`, `pkg_install_in_box`, `pkg_install_if_missing_in_box`, `ensure_commands`
- **`toolboxes/*.ini`** - Distrobox profiles (NAME, IMAGE, INIT, EXTRA_ARGS, PREINSTALL)
- **`templates/quadlets/`** - Quadlet templates (currently empty, for future use)

## Install Media
- **`bin/fcos-usb-image`** - Builds a bootable FCOS raw disk image (USB-boot) using `coreos-installer install` on a loop device + an Ignition config it generates.

## Core Concepts
1. **Two-box model**: "userland" box (apps) + "desktop" box (session/display). `dx-app` installs in source, exports `.desktop` files to target.
2. **Quadlets**: User-level systemd containers live in `~/.config/containers/systemd/<name>.container`.
3. **Profile-driven**: Box creation is declarative via INI files, not ad-hoc commands.

## Script Patterns
All scripts in `bin/` follow this structure:
```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/../lib/common.sh"
# ... usage() function with heredoc
# ... argument parsing with case/esac
# ... main logic
```

## Key Conventions
- **Rootless-first**: Never assume root. Use `sudo -n ... || ...` fallback pattern.
- **Multi-distro package manager**: Loop through `dnf microdnf yum apt-get apt zypper pacman apk xbps-install`.
- **Prefer shared pkg helpers**: Reuse `pkg_install` (host/container) and `pkg_install_in_box` (inside distrobox) instead of re-embedding installer snippets.
- **GUI boxes are explicit**: For compositors (niri/Hyprland) pass devices via distrobox `--additional-flags` (e.g. `--device /dev/dri --device /dev/input`) and optionally mount the host system bus socket when needed.
- **Idempotent**: Check `podman container exists` before creating; operations should be safe to repeat.
- **Environment overrides**: Use `${VAR:-default}` pattern (e.g., `DX_SOURCE_BOX`, `DX_DESKTOP_BOX`).
- **Exit on error**: All scripts use `set -euo pipefail`.

## Adding New Features
- **New CLI tool**: Create `bin/<tool>`, source `lib/common.sh`, follow existing arg-parsing pattern.
- **New distrobox profile**: Add `toolboxes/<name>.ini` with NAME, IMAGE, INIT, EXTRA_ARGS, PREINSTALL.
- **New quadlet template**: Add to `templates/quadlets/` (reserved for declarative service definitions).
- **Shared functionality**: Extract to `lib/common.sh` if reusable across scripts.

## Testing Locally
```bash
bin/detect-env                                    # verify host vs container
bin/dbx-create toolboxes/userland.ini --yes      # create from profile
bin/dx-app install-export firefox                 # install + export app
bin/quadlet-new myservice --image ... --autostart # create user quadlet
```

## Non-Negotiables (from project principles)
- Minimal host assumptions: check dependencies with `ensure_commands`, guide gracefully if missing.
- Safe defaults: no network exposure, no privileged containers, no broad mounts without explicit opt-in.
- Clear state model: distrobox state in podman, quadlets in `~/.config/containers/systemd/`.
