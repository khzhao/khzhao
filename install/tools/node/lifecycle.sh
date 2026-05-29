#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  fi
}

check_nvm() {
  load_nvm
  command -v nvm >/dev/null 2>&1
}

check_node() {
  load_nvm
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

install_nvm() {
  command -v curl >/dev/null 2>&1 || tool_die "curl is required to install nvm"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "PROFILE=/dev/null bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'"
    return
  fi

  PROFILE=/dev/null bash -c \
    'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
  load_nvm
}

install_node() {
  if check_node; then
    return 0
  fi

  check_nvm || install_nvm
  load_nvm
  command -v nvm >/dev/null 2>&1 || tool_die "nvm was not found after installation"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "nvm install --lts"
    echo "nvm alias default 'lts/*'"
    echo "nvm use default"
    return
  fi

  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
  check_node || tool_die "node/npm were not found after installation"
}

case "${1:-}" in
  check)
    check_node
    ;;
  install)
    install_node
    ;;
  doctor)
    check_node && tool_ok "node available: $(command -v node)" || tool_fail "node/npm missing"
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|doctor}"
    ;;
esac
