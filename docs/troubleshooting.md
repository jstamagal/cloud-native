# Troubleshooting

## Quick doctor run
```bash
bin/doctor
```
- Checks: podman rootless, distrobox present, `systemctl --user` reachable, quadlet unit dir writable.
- Fails on system bus issues: enable linger or start a user session if `systemctl --user` is unreachable.

## Common issues
- **Podman not rootless**: configure subuids/subgids; avoid running as root; `podman info --format '{{.Host.Security.Rootless}}'` should be `true`.
- **User systemd missing**: log in via a session that has a user bus; `loginctl enable-linger "$USER"` if you need services at boot.
- **DBus system bus socket missing** (for GUI boxes with `GUI_SYSTEM_BUS=1`): ensure host has `dbus`/`dbus-broker` running; the socket must exist before creating the box.
- **Package installs flaky across distros**: scripts use `pkg_install_if_missing(_in_box)`; rerun commands—they are idempotent.
- **Container already exists**: `bin/dbx-create` will fail fast; remove or rename the existing Podman container.

## Logs
- Quadlet/services: `journalctl --user -u <name>.service` or `podman logs <container>`.
- Distrobox containers: `podman logs <box-name>` and `distrobox enter --name <box> -- bash` for inspection.

## Re-running exports
- Safe to rerun `dx-app install-export ...`; installs are idempotent and exports overwrite desktop entries.

## FCOS USB bootstrap issues
- If first-boot clone fails: `sudo systemctl restart cloud-native-bootstrap.service` after networking is up.
- Verify Ignition applied: user exists, SSH key present, `/var/home/<user>/cloud-native` cloned.
