#!/usr/bin/env bash

has_system_package_manager() {
  command -v brew >/dev/null 2>&1 ||
    command -v apt-get >/dev/null 2>&1 ||
    command -v dnf >/dev/null 2>&1 ||
    command -v pacman >/dev/null 2>&1
}

install_system_package() {
  local pkg
  pkg="$1"

  if command -v brew >/dev/null 2>&1; then
    brew install "$pkg"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "$pkg"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed "$pkg"
  else
    echo "No supported package manager found for $pkg" >&2
    return 1
  fi
}
