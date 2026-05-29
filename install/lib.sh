#!/usr/bin/env bash

KHZHAO_HOME="${KHZHAO_HOME:-$HOME/.khzhao}"
KHZHAO_LOCAL_BIN="${KHZHAO_LOCAL_BIN:-$HOME/.local/bin}"
KHZHAO_BACKUP_DIR="${KHZHAO_BACKUP_DIR:-$KHZHAO_HOME/backups}"
KHZHAO_TMP_DIR="${KHZHAO_TMP_DIR:-$KHZHAO_HOME/tmp}"
DRY_RUN="${DRY_RUN:-0}"

export PATH="$KHZHAO_LOCAL_BIN:$PATH"

tool_die() {
  echo "$(basename "${BASH_SOURCE[1]}"): $*" >&2
  exit 1
}

tool_warn() {
  echo "$(basename "${BASH_SOURCE[1]}"): $*" >&2
}

tool_ok() {
  printf '[ok] %s\n' "$*"
}

tool_fail() {
  printf '[fail] %s\n' "$*"
  return 1
}

tool_timestamp() {
  date '+%Y-%m-%dT%H-%M-%S'
}

tool_path_is_khzhao_owned() {
  case "$1" in
    "$KHZHAO_HOME"/*) return 0 ;;
    *) return 1 ;;
  esac
}

tool_safe_rm_rf() {
  local path
  path="$1"

  case "$path" in
    ""|"/"|"$HOME"|"$HOME/"|"$KHZHAO_HOME")
      tool_die "refusing to remove unsafe path: $path"
      ;;
  esac

  tool_path_is_khzhao_owned "$path" || tool_die "refusing to remove path outside KHZHAO_HOME: $path"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "rm -rf $path"
  else
    rm -rf "$path"
  fi
}

tool_backup_target() {
  local target backup_root backup_path
  target="$1"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi

  backup_root="$KHZHAO_BACKUP_DIR/$(tool_timestamp)"
  backup_path="$backup_root/$(basename "$target")"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "mv $target $backup_path"
    return 0
  fi

  mkdir -p "$backup_root"
  if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
    backup_path="$backup_path.$$"
  fi
  mv "$target" "$backup_path"
}

tool_version_at_least() {
  local actual required
  actual="$1"
  required="$2"

  awk -v actual="$actual" -v required="$required" '
    BEGIN {
      split(actual, a, /[^0-9]+/)
      split(required, r, /[^0-9]+/)
      for (i = 1; i <= 3; i++) {
        av = a[i] + 0
        rv = r[i] + 0
        if (av > rv) exit 0
        if (av < rv) exit 1
      }
      exit 0
    }
  '
}
