#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$CONFIG_DIR/../../lib.sh"

KHZHAO_REPO="${KHZHAO_REPO:-$(cd -P "$CONFIG_DIR/../../.." && pwd)}"
ZIM_APPNAME="${ZIM_APPNAME:-zim}"
ZIM_REPO_URL="${ZIM_REPO_URL:-https://github.com/NvChad/starter}"
NEOVIM_MIN_VERSION="${NEOVIM_MIN_VERSION:-0.11.0}"
ZIM_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
ZIM_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
ZIM_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
ZIM_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
ZIM_CONFIG_DIR="$ZIM_CONFIG_HOME/$ZIM_APPNAME"
ZIM_DATA_DIR="$ZIM_DATA_HOME/$ZIM_APPNAME"
ZIM_STATE_DIR="$ZIM_STATE_HOME/$ZIM_APPNAME"
ZIM_CACHE_DIR="$ZIM_CACHE_HOME/$ZIM_APPNAME"
ZIM_LAUNCHER="$KHZHAO_LOCAL_BIN/zim"
ZIM_STATE="$KHZHAO_HOME/state/zim.psv"
ZIM_MARKER="# khzhao managed zim launcher"
ZIM_MAPPINGS_SOURCE="$KHZHAO_REPO/share/configs/zim/lua/mappings.lua"
ZIM_MAPPINGS_TARGET="$ZIM_CONFIG_DIR/lua/mappings.lua"

state_value() {
  local key
  key="$1"

  [ -f "$ZIM_STATE" ] || return 1
  awk -F'|' -v key="$key" '$1 == key { print $2; found = 1; exit } END { exit found ? 0 : 1 }' "$ZIM_STATE"
}

nvim_version() {
  command -v nvim >/dev/null 2>&1 || return 1
  nvim --version | sed -n '1s/^NVIM v//p'
}

check_neovim() {
  local version
  version="$(nvim_version)" || return 1
  tool_version_at_least "$version" "$NEOVIM_MIN_VERSION"
}

launcher_managed() {
  [ -f "$ZIM_LAUNCHER" ] && [ ! -L "$ZIM_LAUNCHER" ] && grep -Fqx "$ZIM_MARKER" "$ZIM_LAUNCHER"
}

mappings_managed() {
  [ -f "$ZIM_MAPPINGS_SOURCE" ] &&
    [ -f "$ZIM_MAPPINGS_TARGET" ] &&
    cmp -s "$ZIM_MAPPINGS_SOURCE" "$ZIM_MAPPINGS_TARGET"
}

check_zim() {
  local target launcher appname
  target="$(state_value config 2>/dev/null || true)"
  launcher="$(state_value launcher 2>/dev/null || true)"
  appname="$(state_value appname 2>/dev/null || true)"

  [ "$target" = "$ZIM_CONFIG_DIR" ] &&
    [ "$launcher" = "$ZIM_LAUNCHER" ] &&
    [ "$appname" = "$ZIM_APPNAME" ] &&
    [ -d "$ZIM_CONFIG_DIR" ] &&
    launcher_managed &&
    mappings_managed
}

write_state() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "write $ZIM_STATE"
    return
  fi

  mkdir -p "$(dirname "$ZIM_STATE")"
  {
    printf 'appname|%s\n' "$ZIM_APPNAME"
    printf 'source|%s\n' "$ZIM_REPO_URL"
    printf 'config|%s\n' "$ZIM_CONFIG_DIR"
    printf 'data|%s\n' "$ZIM_DATA_DIR"
    printf 'state|%s\n' "$ZIM_STATE_DIR"
    printf 'cache|%s\n' "$ZIM_CACHE_DIR"
    printf 'launcher|%s\n' "$ZIM_LAUNCHER"
    printf 'mappings|%s\n' "$ZIM_MAPPINGS_TARGET"
  } > "$ZIM_STATE"
}

safe_remove_zim_path() {
  local path
  path="$1"

  case "$path" in
    "$ZIM_CONFIG_HOME/$ZIM_APPNAME"|"$ZIM_DATA_HOME/$ZIM_APPNAME"|"$ZIM_STATE_HOME/$ZIM_APPNAME"|"$ZIM_CACHE_HOME/$ZIM_APPNAME") ;;
    *) tool_die "refusing to remove unmanaged zim path: $path" ;;
  esac

  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "rm -rf $path"
    else
      rm -rf "$path"
    fi
  fi
}

install_launcher() {
  if [ -e "$ZIM_LAUNCHER" ] || [ -L "$ZIM_LAUNCHER" ]; then
    launcher_managed || tool_die "refusing to replace unmanaged launcher: $ZIM_LAUNCHER"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "write $ZIM_LAUNCHER"
    echo "chmod +x $ZIM_LAUNCHER"
    return
  fi

  mkdir -p "$(dirname "$ZIM_LAUNCHER")"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "$ZIM_MARKER"
    printf 'NVIM_APPNAME=%q exec nvim "$@"\n' "$ZIM_APPNAME"
  } > "$ZIM_LAUNCHER"
  chmod +x "$ZIM_LAUNCHER"
}

install_mappings() {
  [ -f "$ZIM_MAPPINGS_SOURCE" ] || tool_die "zim mappings source not found: $ZIM_MAPPINGS_SOURCE"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "install $ZIM_MAPPINGS_SOURCE $ZIM_MAPPINGS_TARGET"
    return
  fi

  mkdir -p "$(dirname "$ZIM_MAPPINGS_TARGET")"
  cp "$ZIM_MAPPINGS_SOURCE" "$ZIM_MAPPINGS_TARGET"
}

install_zim() {
  local owned_config

  if check_zim; then
    return 0
  fi

  command -v git >/dev/null 2>&1 || tool_die "git is required to install zim"
  if [ "$DRY_RUN" -eq 0 ]; then
    check_neovim || tool_die "Neovim >= $NEOVIM_MIN_VERSION is required to install zim"
  fi

  if [ -e "$ZIM_LAUNCHER" ] || [ -L "$ZIM_LAUNCHER" ]; then
    launcher_managed || tool_die "refusing to replace unmanaged launcher: $ZIM_LAUNCHER"
  fi

  owned_config="$(state_value config 2>/dev/null || true)"
  if [ -e "$ZIM_CONFIG_DIR" ] || [ -L "$ZIM_CONFIG_DIR" ]; then
    [ "$owned_config" = "$ZIM_CONFIG_DIR" ] || tool_die "refusing to replace existing zim config: $ZIM_CONFIG_DIR"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "mkdir -p $(dirname "$ZIM_CONFIG_DIR")"
      echo "git clone $ZIM_REPO_URL $ZIM_CONFIG_DIR"
      echo "rm -rf $ZIM_CONFIG_DIR/.git"
    else
      mkdir -p "$(dirname "$ZIM_CONFIG_DIR")"
      if ! git clone "$ZIM_REPO_URL" "$ZIM_CONFIG_DIR"; then
        rm -rf "$ZIM_CONFIG_DIR"
        tool_die "failed to clone NVChad starter"
      fi
      rm -rf "$ZIM_CONFIG_DIR/.git"
    fi
  fi

  install_launcher
  install_mappings
  write_state
}

remove_zim() {
  local config data state cache launcher

  config="$(state_value config 2>/dev/null || true)"
  data="$(state_value data 2>/dev/null || true)"
  state="$(state_value state 2>/dev/null || true)"
  cache="$(state_value cache 2>/dev/null || true)"
  launcher="$(state_value launcher 2>/dev/null || true)"

  if [ -z "$config" ]; then
    if [ -e "$ZIM_CONFIG_DIR" ] || [ -L "$ZIM_CONFIG_DIR" ]; then
      tool_warn "leaving unmanaged zim config in place: $ZIM_CONFIG_DIR"
    fi
  else
    safe_remove_zim_path "$config"
    [ -n "$data" ] && safe_remove_zim_path "$data"
    [ -n "$state" ] && safe_remove_zim_path "$state"
    [ -n "$cache" ] && safe_remove_zim_path "$cache"
  fi

  if [ -n "$launcher" ] && [ "$launcher" = "$ZIM_LAUNCHER" ] && launcher_managed; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "rm $ZIM_LAUNCHER"
    else
      rm "$ZIM_LAUNCHER"
    fi
  elif [ -e "$ZIM_LAUNCHER" ] || [ -L "$ZIM_LAUNCHER" ]; then
    tool_warn "leaving unmanaged launcher in place: $ZIM_LAUNCHER"
  fi

  if [ -f "$ZIM_STATE" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "rm $ZIM_STATE"
    else
      rm "$ZIM_STATE"
    fi
  fi
}

case "${1:-}" in
  check)
    check_zim
    ;;
  install)
    install_zim
    ;;
  uninstall)
    remove_zim
    ;;
  doctor)
    if check_zim; then
      tool_ok "zim profile managed: $ZIM_CONFIG_DIR"
    elif [ -e "$ZIM_CONFIG_DIR" ] || [ -L "$ZIM_CONFIG_DIR" ]; then
      tool_fail "zim config exists but is not khzhao-managed: $ZIM_CONFIG_DIR"
    else
      tool_fail "zim profile missing: $ZIM_CONFIG_DIR"
    fi
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|uninstall|doctor}"
    ;;
esac
