#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

NEOVIM_MIN_VERSION="${NEOVIM_MIN_VERSION:-0.11.0}"
NEOVIM_HOME="${NEOVIM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/neovim}"
NEOVIM_BIN="$NEOVIM_HOME/bin/nvim"
NEOVIM_LINK="$KHZHAO_LOCAL_BIN/nvim"

nvim_version() {
  command -v nvim >/dev/null 2>&1 || return 1
  nvim --version | sed -n '1s/^NVIM v//p'
}

check_neovim() {
  local version
  version="$(nvim_version)" || return 1
  tool_version_at_least "$version" "$NEOVIM_MIN_VERSION"
}

neovim_asset_name() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin)
      case "$arch" in
        arm64|aarch64) echo "nvim-macos-arm64.tar.gz" ;;
        x86_64|amd64) echo "nvim-macos-x86_64.tar.gz" ;;
        *) return 1 ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64|amd64) echo "nvim-linux-x86_64.tar.gz" ;;
        arm64|aarch64) echo "nvim-linux-arm64.tar.gz" ;;
        *) return 1 ;;
      esac
      ;;
    *)
      return 1
      ;;
  esac
}

same_symlink() {
  local target source current
  target="$1"
  source="$2"

  [ -L "$target" ] || return 1
  current="$(readlink "$target")"
  [ "$current" = "$source" ]
}

link_neovim() {
  local current

  if [ -L "$NEOVIM_LINK" ]; then
    current="$(readlink "$NEOVIM_LINK")"
    if [ "$current" != "$NEOVIM_BIN" ]; then
      tool_die "refusing to replace unmanaged nvim symlink: $NEOVIM_LINK -> $current"
    fi
  elif [ -e "$NEOVIM_LINK" ]; then
    tool_die "refusing to replace unmanaged nvim path: $NEOVIM_LINK"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "ln -sfn $NEOVIM_BIN $NEOVIM_LINK"
  else
    mkdir -p "$(dirname "$NEOVIM_LINK")"
    ln -sfn "$NEOVIM_BIN" "$NEOVIM_LINK"
  fi
}

ensure_neovim_install_target_safe() {
  local current

  if [ -L "$NEOVIM_LINK" ]; then
    current="$(readlink "$NEOVIM_LINK")"
    [ "$current" = "$NEOVIM_BIN" ] || tool_die "refusing to replace unmanaged nvim symlink: $NEOVIM_LINK -> $current"
  elif [ -e "$NEOVIM_LINK" ]; then
    tool_die "refusing to replace unmanaged nvim path: $NEOVIM_LINK"
  fi

  if [ -e "$NEOVIM_HOME" ] || [ -L "$NEOVIM_HOME" ]; then
    if ! same_symlink "$NEOVIM_LINK" "$NEOVIM_BIN"; then
      tool_die "refusing to replace existing Neovim install: $NEOVIM_HOME"
    fi
  fi
}

replace_neovim_home() {
  local source
  source="$1"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "rm -rf $NEOVIM_HOME"
    echo "mv <extracted-nvim> $NEOVIM_HOME"
    return
  fi

  rm -rf "$NEOVIM_HOME"
  mkdir -p "$(dirname "$NEOVIM_HOME")"
  mv "$source" "$NEOVIM_HOME"
}

install_neovim() {
  local asset url tmp archive nvim_bin nvim_root

  if check_neovim; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || tool_die "curl is required to install Neovim"
  command -v tar >/dev/null 2>&1 || tool_die "tar is required to install Neovim"
  asset="$(neovim_asset_name)" || tool_die "unsupported platform for official Neovim archive: $(uname -s)/$(uname -m)"
  url="https://github.com/neovim/neovim/releases/latest/download/$asset"
  ensure_neovim_install_target_safe

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "curl -fL $url -o <tmp>/$asset"
    echo "tar -xzf <tmp>/$asset -C <tmp>"
    echo "rm -rf $NEOVIM_HOME"
    echo "mv <extracted-nvim> $NEOVIM_HOME"
    echo "ln -sfn $NEOVIM_BIN $NEOVIM_LINK"
    return
  fi

  mkdir -p "$KHZHAO_TMP_DIR"
  tmp="$(mktemp -d "$KHZHAO_TMP_DIR/neovim.XXXXXX")"
  archive="$tmp/$asset"

  curl -fL "$url" -o "$archive"
  tar -xzf "$archive" -C "$tmp"
  nvim_bin="$(find "$tmp" -type f -path '*/bin/nvim' -print -quit)"
  [ -n "$nvim_bin" ] || tool_die "downloaded Neovim archive did not contain bin/nvim"
  nvim_root="$(cd -P "$(dirname "$nvim_bin")/.." && pwd)"

  replace_neovim_home "$nvim_root"
  rm -rf "$tmp"
  link_neovim
  check_neovim || tool_die "Neovim was not found at required version after installation"
}

case "${1:-}" in
  check)
    check_neovim
    ;;
  install)
    install_neovim
    ;;
  doctor)
    if check_neovim; then
      tool_ok "neovim available: $(command -v nvim) ($(nvim_version))"
    else
      tool_fail "neovim missing or older than $NEOVIM_MIN_VERSION"
    fi
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|doctor}"
    ;;
esac
