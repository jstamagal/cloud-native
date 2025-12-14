# Quickstart

Minimal host → working workspace → first service.

## Prereqs
- Podman (rootless) + distrobox
- User-level systemd available (`systemctl --user` works)
- Basic network access to pull container images

Run a quick check:
```bash
bin/doctor
```

## 1) Create the two-box workspace
```bash
# userland box: where apps/tools are installed
bin/dbx-create toolboxes/userland.ini --yes

# desktop box: where .desktop files live (Wayland session if you run desktop in-container)
bin/dbx-create toolboxes/desktop.ini --yes
```

## 2) Verify environment
```bash
bin/detect-env
```
Expected: `is_container=0` on host; inside a box `is_container=1` and `distrobox_name` set.

## 3) Install and export an app
```bash
DX_SOURCE_BOX=userland \
DX_DESKTOP_BOX=desktop \
bin/dx-app install-export firefox
```
This installs Firefox in `userland` and exports its launcher into `desktop`.

## 4) Scaffold your first service (quadlet)
```bash
bin/quadlet-new registry \
  --image docker.io/library/registry:2 \
  --port 5000:5000 \
  --volume ~/registry:/var/lib/registry \
  --autostart
```
A quadlet `.container` lands in `~/.config/containers/systemd/registry.container`; the service is enabled and started.

## 5) Optional: build a bootable FCOS USB image
```bash
bin/fcos-usb-image --password --ssh-key ~/.ssh/id_ed25519.pub
sudo dd if=out/fcos-usb-$USER/fcos-usb.img of=/dev/sdX bs=4M conv=fsync status=progress
```
Booting from the USB will clone this repo and prepare your user.
