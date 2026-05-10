#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "install.sh: $*" >&2
  exit 1
}

warn() {
  echo "install.sh: $*" >&2
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

run_package_install() {
  local install_root
  install_root="$1"

  if [ "$SKIP_PACKAGES" -eq 1 ]; then
    return 0
  fi

  if [ ! -f "$install_root/install/run.sh" ] || [ ! -r "$install_root/share/manifest/packages.psv" ]; then
    return 2
  fi

  # shellcheck source=install/run.sh
  . "$install_root/install/run.sh"
  install_packages "$install_root/share/manifest/packages.psv" "$FORCE_PACKAGES"
}

usage() {
  cat <<'EOF'
usage: install.sh [--skip-packages] [--force]

Environment:
  KHZHAO_HOME      install root, defaults to ~/.khzhao
  KHZHAO_REPO_URL  git remote, defaults to this checkout or GitHub HTTPS
EOF
}

SCRIPT_DIR="$(resolve_script_dir || true)"
KHZHAO_HOME="${KHZHAO_HOME:-$HOME/.khzhao}"
KHZHAO_REPO="$KHZHAO_HOME/repo"
KHZHAO_REPO_URL="${KHZHAO_REPO_URL:-$(default_repo_url)}"
SKIP_PACKAGES=0
FORCE_PACKAGES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-packages)
      SKIP_PACKAGES=1
      ;;
    --force)
      FORCE_PACKAGES=1
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
  "$KHZHAO_HOME/logs" \
  "$KHZHAO_HOME/tmp"

PACKAGES_INSTALLED=0
if [ -n "$SCRIPT_DIR" ]; then
  PACKAGES_INSTALLED=1
  run_package_install "$SCRIPT_DIR" || {
    status="$?"
    [ "$status" -eq 2 ] || exit "$status"
    PACKAGES_INSTALLED=0
  }
fi

ensure_repo_checkout

if [ "$PACKAGES_INSTALLED" -eq 0 ]; then
  run_package_install "$KHZHAO_REPO" || {
    status="$?"
    [ "$status" -eq 2 ] && warn "package adapters not found; skipping dependency install" || exit "$status"
  }
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$KHZHAO_REPO/khzhao" "$HOME/.local/bin/khzhao"

"$KHZHAO_REPO/khzhao" install
