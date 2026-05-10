#!/usr/bin/env bash

INSTALL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$INSTALL_DIR/packages"

# shellcheck source=install/packages/system.sh
. "$PACKAGES_DIR/system.sh"
# shellcheck source=install/packages/uv.sh
. "$PACKAGES_DIR/uv.sh"
# shellcheck source=install/packages/nvm.sh
. "$PACKAGES_DIR/nvm.sh"
# shellcheck source=install/packages/node.sh
. "$PACKAGES_DIR/node.sh"

check_system_tool() {
  command -v "$1" >/dev/null 2>&1
}

package_installed() {
  local name installer
  name="$1"
  installer="$2"

  case "$installer" in
    system)
      check_system_tool "$name"
      ;;
    uv-official)
      check_uv
      ;;
    nvm-node)
      check_node
      ;;
    *)
      echo "Unknown installer '$installer' for $name" >&2
      return 1
      ;;
  esac
}

install_one_package() {
  local name installer
  name="$1"
  installer="$2"

  case "$installer" in
    system) install_system_package "$name" ;;
    uv-official) install_uv ;;
    nvm-node) install_node ;;
    *)
      echo "Unknown installer '$installer' for $name" >&2
      return 1
      ;;
  esac
}

confirm_install_package() {
  local name description force reply
  name="$1"
  description="$2"
  force="$3"

  if [ "$force" -eq 1 ]; then
    return 0
  fi

  if ! { printf '' > /dev/tty; } 2>/dev/null; then
    echo "Package '$name' is missing and no TTY is available for confirmation." >&2
    echo "Rerun with --force to install missing packages without prompting." >&2
    return 1
  fi

  while true; do
    printf "Install %s (%s)? [Y/n] " "$name" "$description" > /dev/tty
    IFS= read -r reply < /dev/tty || return 1

    case "$reply" in
      ""|[Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
      *) echo "Please answer Y or n." > /dev/tty ;;
    esac
  done
}

install_packages() {
  local manifest force name required installer description
  manifest="$1"
  force="${2:-0}"

  [ -r "$manifest" ] || {
    echo "Package manifest not found: $manifest" >&2
    return 1
  }

  while IFS='|' read -r name required installer description; do
    [ -z "${name:-}" ] && continue
    [ "$name" = "name" ] && continue
    case "$name" in \#*) continue ;; esac

    echo "Checking $name..."
    if package_installed "$name" "$installer"; then
      echo "Found $name."
      continue
    fi

    if confirm_install_package "$name" "$description" "$force"; then
      install_one_package "$name" "$installer"
      if ! package_installed "$name" "$installer"; then
        echo "Package '$name' was not found after install." >&2
        return 1
      fi
    else
      echo "Required package '$name' was not installed." >&2
      return 1
    fi
  done < "$manifest"
}
