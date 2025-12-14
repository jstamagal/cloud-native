# Concepts

## Two-box model
- **Source box (`DX_SOURCE_BOX`, default `userland`)**: where packages/apps are installed.
- **Desktop box (`DX_DESKTOP_BOX`, default `desktop`)**: where `.desktop` files and wrappers live; can host the session if running the desktop in-container.
- **Export flow**: `dx-app install-export` installs in source, exports launchers into desktop.

## Services via quadlets
- User-level systemd units under `~/.config/containers/systemd/<name>.container`.
- Created with `bin/quadlet-new` (defaults: `Restart=on-failure`, `UserNS=keep-id`, `AutoUpdate=registry`).
- Manage with `systemctl --user enable|start|status <name>.service`.

## Package management helpers
- `lib/common.sh` centralizes multi-distro installs:
  - `pkg_install`, `pkg_is_installed`, `pkg_install_if_missing`
  - `pkg_install_in_box`, `pkg_install_if_missing_in_box`
  - `sudo_maybe` handles missing sudo by falling back to direct exec.

## GUI distroboxes
- Profiles can set `GUI=1` to add `--device /dev/dri --device /dev/input` via `--additional-flags`.
- `GUI_SYSTEM_BUS=1` binds `/run/dbus/system_bus_socket` (requires host socket present).
- `ADDITIONAL_FLAGS=` passes straight to `distrobox --additional-flags`.

## State locations
- Distrobox containers: Podman containers (`podman container exists <name>`).
- Quadlets: `~/.config/containers/systemd/`.
- Repo clone (for FCOS USB bootstrap): `/var/home/<user>/cloud-native` (first-boot bootstrap).

## Defaults & env overrides
- `DX_SOURCE_BOX=userland`, `DX_DESKTOP_BOX=desktop`, `DX_DESKTOP_USER=$USER`.
- Scripts use `set -euo pipefail`; assume rootless-first; use `${VAR:-default}` throughout.

## Install media (FCOS USB)
- `bin/fcos-usb-image` builds a bootable FCOS raw image with an Ignition that creates your user, installs SSH authorized_keys, and clones this repo on first boot.
