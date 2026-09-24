#!/usr/bin/env sh
# Regenerate golden files from current plugin output.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh
command -v kak >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip kak not installed')"
  exit 0
}

for f in test/fixtures/*.md; do
  dump=$(mktemp /tmp/rmdump.XXXXXX) || exit 1
  if [ -f "${f%.md}.cursor" ]; then
    ./test/integration/run-fixture.sh render-markdown.kak "$f" "$dump" "$(cat "${f%.md}.cursor")"
  else
    ./test/integration/run-fixture.sh render-markdown.kak "$f" "$dump"
  fi
  cp "$dump" "${f%.md}.golden"
  rm -f "$dump"
  printf '%s\n' "$(cm_yellow "blessed: ${f%.md}.golden")"
done
