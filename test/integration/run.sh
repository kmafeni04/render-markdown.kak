#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh
command -v kak >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip kak not installed')"
  exit 0
}

plugin=render-markdown.kak
# a fixture may carry a <fixture>.cursor file to render from a scrolled
# position (the viewport is what gets rendered, so this exercises scrolling)
n=0
for f in test/fixtures/*.md; do
  case $f in *.md) ;; *) continue ;; esac
  g=${f%.md}.golden
  if [ ! -f "$g" ]; then
    printf 'integration: missing golden %s (run: ./test/run.sh bless)\n' "$g" >&2
    exit 1
  fi
  dump=$(mktemp /tmp/rmdump.XXXXXX) || exit 1
  ./test/integration/run-fixture.sh "$plugin" "$f" "$dump"
  if ! diff -u "$g" "$dump"; then
    printf '%s\n' "$(cm_red "FAIL ${f##*/}")"
    rm -f "$dump"
    exit 1
  fi
  rm -f "$dump"
  n=$((n + 1))
done
printf '%s\n' "$(cm_green "ok $n fixtures")"
