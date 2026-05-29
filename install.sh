#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "install.sh: $*" >&2
  exit 1
}

resolve_script_dir() {
  local source dir link
  source="${BASH_SOURCE[0]:-}"
  [ -n "$source" ] || return 1

  while [ -L "$source" ]; do
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    link="$(readlink "$source")"
    case "$link" in
      /*) source="$link" ;;
      *) source="$dir/$link" ;;
    esac
  done

  cd -P "$(dirname "$source")" && pwd
}

default_repo_url() {
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ]; then
    printf '%s\n' "$SCRIPT_DIR"
  else
    printf '%s\n' "https://github.com/khzhao/khzhao.git"
  fi
}

ensure_repo_checkout() {
  command -v git >/dev/null 2>&1 || die "git is required to install khzhao"

  if [ -d "$KHZHAO_REPO/.git" ]; then
    local target
    git -C "$KHZHAO_REPO" fetch --prune
    target="$(repo_reset_target "$KHZHAO_REPO")"
    git -C "$KHZHAO_REPO" reset --hard "$target"
    return
  fi

  if [ -e "$KHZHAO_REPO" ]; then
    die "$KHZHAO_REPO exists but is not a git checkout"
  fi

  git clone "$KHZHAO_REPO_URL" "$KHZHAO_REPO"
}

repo_reset_target() {
  local repo upstream branch
  repo="$1"

  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [ -n "$upstream" ]; then
    printf '%s\n' "$upstream"
    return
  fi

  branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
  [ -n "$branch" ] || branch="main"
  printf 'origin/%s\n' "$branch"
}

usage() {
  cat <<'EOF'
usage: install.sh [--skip-tools]

Environment:
  KHZHAO_HOME      install root, defaults to ~/.khzhao
  KHZHAO_REPO_URL  git remote, defaults to this checkout or GitHub HTTPS
EOF
}

SCRIPT_DIR="$(resolve_script_dir || true)"
KHZHAO_HOME="${KHZHAO_HOME:-$HOME/.khzhao}"
KHZHAO_REPO="$KHZHAO_HOME/repo"
KHZHAO_REPO_URL="${KHZHAO_REPO_URL:-$(default_repo_url)}"
SKIP_TOOLS=0
FORCE_INSTALL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-tools)
      SKIP_TOOLS=1
      ;;
    --force)
      # Accepted for compatibility with older installers. khzhao uses it to refresh managed shell blocks.
      FORCE_INSTALL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

mkdir -p \
  "$KHZHAO_HOME" \
  "$KHZHAO_HOME/state" \
  "$KHZHAO_HOME/backups" \
  "$KHZHAO_HOME/tmp"

ensure_repo_checkout

set --
if [ "$SKIP_TOOLS" -eq 1 ]; then
  set -- "$@" --skip-tools
fi
if [ "$FORCE_INSTALL" -eq 1 ]; then
  set -- "$@" --force
fi
KHZHAO_HOME="$KHZHAO_HOME" \
KHZHAO_REPO="$KHZHAO_REPO" \
  "$KHZHAO_REPO/khzhao" install "$@"
