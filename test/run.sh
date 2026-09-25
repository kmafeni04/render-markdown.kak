#!/usr/bin/env sh
# render-markdown.kak local test runner (POSIX; also run as: dash test/run.sh)
set -eu
case $0 in */*) cd "${0%/*}" ;; esac # POSIX dirname substitute

# shellcheck disable=SC1091  # color.sh is linted separately
. ./color.sh

# print a bold section header with a blank line before it
header() {
  printf '\n%s\n' "$(cm_bold "$1")"
}

cmd=${1:-all}
case $cmd in
  unit)
    header 'Unit tests:'
    dash ./unit/run.sh
    ;;
  integration)
    header 'Integration tests:'
    ./integration/run.sh
    ;;
  smoke)
    header 'Smoke test:'
    ./integration/smoke.sh
    ;;
  format)
    header 'Format test:'
    ./integration/format.sh
    ;;
  bless)
    header 'Bless goldens:'
    ./integration/bless.sh
    ;;
  lint)
    header 'Lint:'
    dash ./lint.sh
    ;;
  all)
    header 'Unit tests:'
    dash ./unit/run.sh
    header 'Integration tests:'
    ./integration/run.sh
    header 'Smoke test:'
    ./integration/smoke.sh
    header 'Format test:'
    ./integration/format.sh
    header 'Lint:'
    dash ./lint.sh
    ;;
  *)
    printf 'usage: test/run.sh [unit|integration|smoke|format|bless|lint|all]\n' >&2
    exit 2
    ;;
esac
