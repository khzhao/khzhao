#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

LEGACY_VIM_HOME="$KHZHAO_HOME/vim"
LEGACY_NERDTREE_BOOKMARKS="$HOME/.NERDTreeBookmarks"

cleanup_legacy_vim() {
  local mode
  mode="$1"

  if [ -d "$LEGACY_VIM_HOME" ] || [ -L "$LEGACY_VIM_HOME" ]; then
    tool_safe_rm_rf "$LEGACY_VIM_HOME"
  fi

  if [ -e "$LEGACY_NERDTREE_BOOKMARKS" ] || [ -L "$LEGACY_NERDTREE_BOOKMARKS" ]; then
    if [ "$mode" = "uninstall" ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "rm -f $LEGACY_NERDTREE_BOOKMARKS"
      else
        rm -f "$LEGACY_NERDTREE_BOOKMARKS"
      fi
    else
      tool_backup_target "$LEGACY_NERDTREE_BOOKMARKS"
    fi
  fi
}

case "${1:-}" in
  check)
    [ ! -e "$LEGACY_VIM_HOME" ] && [ ! -L "$LEGACY_VIM_HOME" ] &&
      [ ! -e "$LEGACY_NERDTREE_BOOKMARKS" ] && [ ! -L "$LEGACY_NERDTREE_BOOKMARKS" ]
    ;;
  install)
    cleanup_legacy_vim backup
    ;;
  uninstall)
    cleanup_legacy_vim uninstall
    ;;
  doctor)
    if [ -e "$LEGACY_VIM_HOME" ] || [ -L "$LEGACY_VIM_HOME" ]; then
      tool_fail "legacy Vim plugin directory remains: $LEGACY_VIM_HOME"
    elif [ -e "$LEGACY_NERDTREE_BOOKMARKS" ] || [ -L "$LEGACY_NERDTREE_BOOKMARKS" ]; then
      tool_fail "legacy NERDTree bookmarks remain: $LEGACY_NERDTREE_BOOKMARKS"
    else
      tool_ok "legacy Vim artifacts cleaned"
    fi
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|uninstall|doctor}"
    ;;
esac
