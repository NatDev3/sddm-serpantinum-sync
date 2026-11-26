#!/usr/bin/env bash
# Bootstrap for SDDM Serpantinum Sync.
# Downloads the installer, then runs it.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NatDev3/sddm-serpantinum-sync/main/install/bootstrap.sh | bash
set -e

main() {
  local slug="${REPO_SLUG:-NatDev3/sddm-serpantinum-sync}"
  local branch="${SDDM_SYNC_BRANCH:-main}"
  local dir
  dir="$(mktemp -d)"
  trap 'rm -rf "$dir"' EXIT

  curl -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install.sh"

  if [ -t 0 ]; then
    bash "$dir/install.sh" "$@"
  elif [ -r /dev/tty ]; then
    bash "$dir/install.sh" "$@" < /dev/tty
  else
    bash "$dir/install.sh" "$@"
  fi
}

main "$@"
