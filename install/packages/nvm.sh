#!/usr/bin/env bash

load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

check_nvm() {
  load_nvm
  command -v nvm >/dev/null 2>&1
}

install_nvm() {
  PROFILE=/dev/null bash -c \
    'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
  load_nvm
}

verify_nvm() {
  load_nvm
  command -v nvm >/dev/null 2>&1
}
