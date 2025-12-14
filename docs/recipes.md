# Recipes

## GUI-ready desktop box
Use the profile knobs for devices and system bus:
```bash
# example profile snippet
NAME=desktop
IMAGE=quay.io/fedora-ostree-desktops/kinoite:41
GUI=1
GUI_SYSTEM_BUS=1
ADDITIONAL_FLAGS="--device /dev/dri --device /dev/input"
PREINSTALL="niri-wayland xwayland xdg-desktop-portal xdg-desktop-portal-gtk"
```
Then create:
```bash
bin/dbx-create toolboxes/desktop.ini --yes
```

## Minimal dev toolbox (Arch)
```bash
NAME=dev-arch
IMAGE=quay.io/toolbx/archlinux-toolbox:latest
INIT=1
EXTRA_ARGS=--yes
PREINSTALL="base-devel git neovim podman-compose"
```

## Exporting multiple apps at once
```bash
DX_SOURCE_BOX=userland DX_DESKTOP_BOX=desktop \
  bin/dx-app install-export firefox code:code thunderbird
```
- `pkg:AppId` installs `pkg` but exports the launcher as `AppId`.
- `:AppId` only exports an already-installed app.

## User-level quadlet for a registry
```bash
bin/quadlet-new registry \
  --image docker.io/library/registry:2 \
  --port 5000:5000 \
  --volume ~/registry:/var/lib/registry \
  --autostart
```

## Bootable FCOS USB (run-from-USB)
```bash
bin/fcos-usb-image --password --ssh-key ~/.ssh/id_ed25519.pub
sudo dd if=out/fcos-usb-$USER/fcos-usb.img of=/dev/sdX bs=4M conv=fsync status=progress
```
Boot it on diskless or any machine; first boot clones this repo and sets up your user.

## Quick FCOS USB debug in QEMU (UEFI)
```bash
# build the image if you haven't yet
bin/fcos-usb-image --password-hash '<hash>' --ssh-key ~/.ssh/id_ed25519.pub --no-build

# boot it safely with snapshot mode and SSH forward on 2222
bin/fcos-usb-qemu --image out/fcos-usb-$USER/fcos-usb.img
```
- Requires `qemu-system-x86_64` and OVMF firmware (package: `edk2-ovmf` on Fedora).
- Defaults: snapshot=on (base image untouched), KVM if available, 4 vCPUs, 4 GiB RAM,
  UEFI boot, and `127.0.0.1:2222 -> guest:22`.
- Disable port forward: `--ssh-port 0`; make writes persistent: `--no-snapshot`;
  prefer a GUI window: `--gui`.

### One-shot build + boot
```bash
# build, then immediately boot it in QEMU with defaults
bin/fcos-usb-image --password-hash '<hash>' --ssh-key ~/.ssh/id_ed25519.pub --run-qemu
```
- Add `--qemu-gui` for a window, `--qemu-no-kvm` if KVM is unavailable, or pass extra
  QEMU args after `--` (e.g., `-- -device usb-tablet`).
