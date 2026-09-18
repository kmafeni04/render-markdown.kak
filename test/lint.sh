#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")" || true
. ./color.sh
command -v shellcheck >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip shellcheck not installed')"
  exit 0
}
find . -name '*.sh' -exec shellcheck -s dash {} + || exit 1
printf '%s\n' "$(cm_green 'ok shellcheck clean')"
