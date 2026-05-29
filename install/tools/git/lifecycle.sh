#!/usr/bin/env bash
set -euo pipefail

TOOL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib.sh
. "$TOOL_DIR/../../lib.sh"

check_git() {
  command -v git >/dev/null 2>&1
}

case "${1:-}" in
  check)
    check_git
    ;;
  install)
    check_git || tool_die "git is required but is not installed; install Git with your system administrator or platform package manager"
    ;;
  doctor)
    check_git && tool_ok "git available: $(command -v git)" || tool_fail "git missing"
    ;;
  *)
    tool_die "usage: lifecycle.sh {check|install|doctor}"
    ;;
esac
