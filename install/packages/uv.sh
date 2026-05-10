#!/usr/bin/env bash

check_uv() {
  command -v uv >/dev/null 2>&1
}

install_uv() {
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
}

verify_uv() {
  command -v uv >/dev/null 2>&1
}
