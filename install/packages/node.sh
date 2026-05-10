#!/usr/bin/env bash

check_node() {
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

install_node() {
  check_nvm || install_nvm
  verify_nvm
  load_nvm
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
}

verify_node() {
  if check_nvm; then
    nvm use default >/dev/null 2>&1 || true
  fi
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}
