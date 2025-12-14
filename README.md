# Cloud-Native Desktop Kit (FCOS)

Helper scripts that turn Fedora CoreOS into a comfortable desktop + development platform built entirely from containers (distrobox/toolbox + podman/quadlets).

## What’s here
- `bin/detect-env` – report whether you’re on host or inside a container plus distro info.
- `bin/dbx-create` – create distroboxes/toolboxes from simple profiles in `toolboxes/*.ini`, optionally preinstalling packages.
- `bin/dx-app` – install packages inside a “userland” box and export launchers into a “desktop” box (useful when the desktop session itself lives in a container).
- `bin/quadlet-new` – scaffold a user-level quadlet (`~/.config/containers/systemd/<name>.container`) and optionally enable it.
- `bin/doctor` – check prerequisites (rootless podman, distrobox, systemd user) and suggest fixes.
- `lib/common.sh` – shared utilities (distro detection, pkg-install helpers).

## Opinions / defaults
- Source box (where apps are built/installed): `DX_SOURCE_BOX=userland`
- Desktop box (where .desktop + wrappers should live): `DX_DESKTOP_BOX=desktop`
- Desktop box user: `DX_DESKTOP_USER=$USER`

## Quickstart
```bash
# sanity check your host prerequisites
bin/doctor

# create baseline boxes from profiles
bin/dbx-create toolboxes/userland.ini --yes --auto-name --hostname random
bin/dbx-create toolboxes/desktop.ini --yes --auto-name --hostname random

# verify where you are
bin/detect-env

# install firefox inside userland and export launcher into desktop box
DX_SOURCE_BOX=userland DX_DESKTOP_BOX=desktop bin/dx-app install-export firefox

# scaffold a podman quadlet for a local registry
bin/quadlet-new registry --image docker.io/library/registry:2 \
  --port 5000:5000 --volume ~/registry:/var/lib/registry --autostart
```

## Build a bootable FCOS USB image
This generates a **raw disk image** you can `dd` to a USB stick and boot directly.

Security notes:
- Provide a `--password-hash` if you don’t want to type a password into the tool.
- Only **public** SSH keys are embedded (authorized_keys). Private keys are never copied.

```bash
bin/fcos-usb-image --password --ssh-key ~/.ssh/id_ed25519.pub

# then write to a USB drive (DESTROYING its contents)
sudo dd if=out/fcos-usb-$USER/fcos-usb.img of=/dev/sdX bs=4M conv=fsync status=progress
```

## dx-app mapping syntax
- `pkg` → install `pkg`, export app id `pkg`
- `pkg:AppId` → install `pkg`, export desktop entry `AppId`
- `:AppId` → just export an already-installed app

Example: install VS Code (RPM) but export desktop id `code`:
```bash
bin/dx-app install-export code:code
```

## Adding new distrobox profiles
Create `toolboxes/<name>.ini`:
```
NAME=mybox
IMAGE=registry.fedoraproject.org/fedora-toolbox:41
INIT=1
EXTRA_ARGS=--yes --pull
ADDITIONAL_FLAGS=--device /dev/dri --device /dev/input
GUI=0
GUI_SYSTEM_BUS=0
PREINSTALL=git make curl
```
Then `bin/dbx-create toolboxes/mybox.ini --yes`.

### Auto-naming and hostnames
- `--auto-name` generates a name as `<profile>-<hostname>` (e.g., `desktop-thunderhawk`).
- `--hostname NAME|random` sets the distrobox hostname; `random` picks a codename.

## Quadlets in a nutshell
- Files land in `~/.config/containers/systemd/<name>.container`.
- `--autostart` tells `quadlet-new` to `systemctl --user enable --now <name>.service`.
- Use `podman generate systemd --new` if you need a baseline, then translate fields into the script’s flags.

## Notes / next ideas
- Add presets for Wayland shells (niri, sway), GPU passthrough, and PipeWire/portal bridges.
- Hook into `flatpak-spawn` for exporting Flatpak-friendly launchers when running a desktop inside a box.
- Optional kcli/bootc flows for rebuilding FCOS with these defaults baked in.

## Docs
- `docs/quickstart.md` — minimal host → workspace → first service
- `docs/concepts.md` — two-box model, quadlets, package helpers, state
- `docs/recipes.md` — GUI boxes, dev boxes, exports, quadlet examples, FCOS USB
- `docs/troubleshooting.md` — doctor checks, common failures, logs
