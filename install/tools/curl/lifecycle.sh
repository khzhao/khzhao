#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

check_curl() {
  command -v curl >/dev/null 2>&1
}

case "${1:-}" in
  check)
    check_curl
    ;;
  install)
    check_curl || tool_die "curl is required but is not installed; install curl with your system administrator or platform package manager"
    ;;
  doctor)
    check_curl && tool_ok "curl available: $(command -v curl)" || tool_fail "curl missing"
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|doctor}"
    ;;
esac
