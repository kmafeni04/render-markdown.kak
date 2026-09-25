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

# run_one <test>: print its header and run it; fails for an unknown name
run_one() {
  case $1 in
    unit)        header 'Unit tests:';        dash ./unit/run.sh ;;
    integration) header 'Integration tests:'; ./integration/run.sh ;;
    smoke)       header 'Smoke test:';        ./integration/smoke.sh ;;
    format)      header 'Format test:';       ./integration/format.sh ;;
    cache)       header 'Cache test:';        ./integration/cache.sh ;;
    bless)       header 'Bless goldens:';     ./integration/bless.sh ;;
    lint)        header 'Lint:';              dash ./lint.sh ;;
    *)           return 1 ;;
  esac
}

# bless is not part of the default run
cmd=${1:-all}
if [ "$cmd" = all ]; then
  for t in unit integration smoke format cache lint; do run_one "$t"; done
elif ! run_one "$cmd"; then
  printf 'usage: test/run.sh [unit|integration|smoke|format|cache|bless|lint|all]\n' >&2
  exit 2
fi
