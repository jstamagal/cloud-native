#!/usr/bin/env bash
# Shared helpers for the cloud-native desktop toolkit.
# Keep this file POSIX-ish enough to run inside most distroboxes and toolboxes.

set -o pipefail

log() {
  # shellcheck disable=SC2059
  printf "%s\n" "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

sudo_maybe() {
  # Run a command via sudo if available and non-interactive; otherwise run directly.
  # Works in minimal containers that may not ship sudo.
  if have sudo; then
    sudo -n "$@" 2>/dev/null || "$@"
  else
    "$@"
  fi
}

require_system_bus_socket() {
  sock=${1:-/run/dbus/system_bus_socket}
  if [ ! -S "$sock" ]; then
    die "system D-Bus socket not found at $sock (install/enable dbus or dbus-broker on the host)"
  fi
}

detect_os_id() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf "%s" "${ID:-unknown}"
  else
    printf "unknown"
  fi
}

detect_pretty_name() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf "%s" "${PRETTY_NAME:-${NAME:-unknown}}"
  else
    printf "unknown"
  fi
}

detect_pkg_manager() {
  for pm in dnf microdnf yum apt-get apt zypper pacman apk xbps-install; do
    if have "$pm"; then
      printf "%s" "$pm"
      return 0
    fi
  done
  return 1
}

pkg_is_installed() {
  # Usage: pkg_is_installed <pkg>
  pkg=$1
  [ -n "$pkg" ] || return 1
  pm=$(detect_pkg_manager 2>/dev/null || true)
  [ -n "$pm" ] || return 1

  case "$pm" in
    dnf|microdnf|yum|zypper)
      have rpm && rpm -q "$pkg" >/dev/null 2>&1
      ;;
    apt-get|apt)
      have dpkg-query && dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
      ;;
    pacman)
      pacman -Qi "$pkg" >/dev/null 2>&1
      ;;
    apk)
      apk info -e "$pkg" >/dev/null 2>&1
      ;;
    xbps-install)
      have xbps-query && xbps-query -p pkgver "$pkg" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

pkg_update() {
  # Best-effort metadata refresh. Some package managers (dnf/yum/microdnf) will
  # refresh as part of install; keep this lightweight.
  pm=$(detect_pkg_manager) || die "no supported package manager found"
  case "$pm" in
    apt-get|apt)
      sudo_maybe apt-get update
      ;;
    zypper)
      sudo_maybe zypper --non-interactive refresh
      ;;
    pacman)
      sudo_maybe pacman -Sy --noconfirm
      ;;
    apk)
      sudo_maybe apk update
      ;;
    xbps-install)
      sudo_maybe xbps-install -S
      ;;
    dnf|microdnf|yum)
      :
      ;;
    *)
      die "unsupported package manager: $pm"
      ;;
  esac
}

pkg_install() {
  # Install packages using the detected package manager.
  # Usage: pkg_install pkg1 pkg2 ...
  [ "$#" -gt 0 ] || die "pkg_install: no packages provided"
  pm=$(detect_pkg_manager) || die "no supported package manager found"
  case "$pm" in
    dnf|microdnf|yum)
      sudo_maybe "$pm" -y install "$@"
      ;;
    apt-get|apt)
      sudo_maybe apt-get update >/dev/null 2>&1 || apt-get update
      sudo_maybe apt-get install -y "$@"
      ;;
    zypper)
      sudo_maybe zypper --non-interactive install "$@"
      ;;
    pacman)
      sudo_maybe pacman -Syu --noconfirm --needed "$@"
      ;;
    apk)
      sudo_maybe apk add "$@"
      ;;
    xbps-install)
      sudo_maybe xbps-install -Sy "$@"
      ;;
    *)
      die "unsupported package manager: $pm"
      ;;
  esac
}

pkg_install_if_missing() {
  # Usage: pkg_install_if_missing pkg1 pkg2 ...
  [ "$#" -gt 0 ] || die "pkg_install_if_missing: no packages provided"
  to_install=()
  for pkg in "$@"; do
    if ! pkg_is_installed "$pkg"; then
      to_install+=("$pkg")
    fi
  done
  [ "${#to_install[@]}" -gt 0 ] || return 0
  pkg_install "${to_install[@]}"
}

pkg_install_in_box() {
  # Install packages inside a distrobox/toolbox.
  # Usage: pkg_install_in_box <box-name> pkg1 pkg2 ...
  box=$1
  shift
  [ "$#" -gt 0 ] || return 0
  ensure_commands distrobox

  distrobox enter --name "$box" -- /bin/sh -s "$@" <<'EOF'
set -e
have() { command -v "$1" >/dev/null 2>&1; }
sudo_maybe() {
  if have sudo; then
    sudo -n "$@" 2>/dev/null || "$@"
  else
    "$@"
  fi
}

pm=""
for c in dnf microdnf yum apt-get apt zypper pacman apk xbps-install; do
  have "$c" && { pm=$c; break; }
done
[ -n "$pm" ] || { echo "no supported package manager found" >&2; exit 1; }

case "$pm" in
  dnf|microdnf|yum)
    sudo_maybe "$pm" -y install "$@"
    ;;
  apt-get|apt)
    sudo_maybe apt-get update >/dev/null 2>&1 || apt-get update
    sudo_maybe apt-get install -y "$@"
    ;;
  zypper)
    sudo_maybe zypper --non-interactive refresh >/dev/null 2>&1 || true
    sudo_maybe zypper --non-interactive install "$@"
    ;;
  pacman)
    sudo_maybe pacman -Syu --noconfirm --needed "$@"
    ;;
  apk)
    sudo_maybe apk add "$@"
    ;;
  xbps-install)
    sudo_maybe xbps-install -Sy "$@"
    ;;
  *)
    echo "unsupported package manager: $pm" >&2
    exit 1
    ;;
esac
EOF
}

pkg_install_if_missing_in_box() {
  # Usage: pkg_install_if_missing_in_box <box-name> pkg1 pkg2 ...
  box=$1
  shift
  [ "$#" -gt 0 ] || return 0
  ensure_commands distrobox

  distrobox enter --name "$box" -- /bin/sh -s "$@" <<'EOF'
set -e
have() { command -v "$1" >/dev/null 2>&1; }
sudo_maybe() {
  if have sudo; then
    sudo -n "$@" 2>/dev/null || "$@"
  else
    "$@"
  fi
}

pm=""
for c in dnf microdnf yum apt-get apt zypper pacman apk xbps-install; do
  have "$c" && { pm=$c; break; }
done
[ -n "$pm" ] || { echo "no supported package manager found" >&2; exit 1; }

is_installed() {
  pkg=$1
  case "$pm" in
    dnf|microdnf|yum|zypper)
      have rpm && rpm -q "$pkg" >/dev/null 2>&1
      ;;
    apt-get|apt)
      have dpkg-query && dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
      ;;
    pacman)
      pacman -Qi "$pkg" >/dev/null 2>&1
      ;;
    apk)
      apk info -e "$pkg" >/dev/null 2>&1
      ;;
    xbps-install)
      have xbps-query && xbps-query -p pkgver "$pkg" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

to_install=""
for pkg in "$@"; do
  if ! is_installed "$pkg"; then
    to_install="$to_install $pkg"
  fi
done

[ -n "$to_install" ] || exit 0
set -- $to_install

case "$pm" in
  dnf|microdnf|yum)
    sudo_maybe "$pm" -y install "$@"
    ;;
  apt-get|apt)
    sudo_maybe apt-get update >/dev/null 2>&1 || apt-get update
    sudo_maybe apt-get install -y "$@"
    ;;
  zypper)
    sudo_maybe zypper --non-interactive refresh >/dev/null 2>&1 || true
    sudo_maybe zypper --non-interactive install "$@"
    ;;
  pacman)
    sudo_maybe pacman -Syu --noconfirm --needed "$@"
    ;;
  apk)
    sudo_maybe apk add "$@"
    ;;
  xbps-install)
    sudo_maybe xbps-install -Sy "$@"
    ;;
  *)
    echo "unsupported package manager: $pm" >&2
    exit 1
    ;;
esac
EOF
}

ensure_commands() {
  missing=0
  for cmd in "$@"; do
    if ! have "$cmd"; then
      log "missing dependency: $cmd"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || die "please install missing dependencies above"
}

require_rootless_podman() {
  ensure_commands podman
  if ! podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q true; then
    die "podman rootless is required (run as your user; check subuids/subgids)"
  fi
}

