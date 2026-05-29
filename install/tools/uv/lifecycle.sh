#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

check_uv() {
  command -v uv >/dev/null 2>&1
}

install_uv() {
  if check_uv; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || tool_die "curl is required to install uv"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh"
    return
  fi

  curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
  export PATH="$HOME/.local/bin:$PATH"
  check_uv || tool_die "uv was not found after installation"
}

case "${1:-}" in
  check)
    check_uv
    ;;
  install)
    install_uv
    ;;
  doctor)
    check_uv && tool_ok "uv available: $(command -v uv)" || tool_fail "uv missing"
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|doctor}"
    ;;
esac
