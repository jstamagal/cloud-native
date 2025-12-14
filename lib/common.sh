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

pkg_install() {
  # Install packages using the detected package manager.
  # Usage: pkg_install pkg1 pkg2 ...
  [ "$#" -gt 0 ] || die "pkg_install: no packages provided"
  pm=$(detect_pkg_manager) || die "no supported package manager found"
  case "$pm" in
    dnf|microdnf|yum)
      sudo -n "$pm" -y install "$@" || "$pm" -y install "$@"
      ;;
    apt-get|apt)
      sudo -n apt-get update >/dev/null 2>&1 || apt-get update
      sudo -n apt-get install -y "$@" || apt-get install -y "$@"
      ;;
    zypper)
      sudo -n zypper --non-interactive install "$@" || zypper --non-interactive install "$@"
      ;;
    pacman)
      sudo -n pacman -Syu --noconfirm "$@" || pacman -Syu --noconfirm "$@"
      ;;
    apk)
      sudo -n apk add "$@" || apk add "$@"
      ;;
    xbps-install)
      sudo -n xbps-install -Sy "$@" || xbps-install -Sy "$@"
      ;;
    *)
      die "unsupported package manager: $pm"
      ;;
  esac
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

