#!/usr/bin/env sh
# usage: run-fixture.sh <plugin> <fixture> <dumpfile>
# Runs one fixture in a headless kakoune (json ui) and captures the emitted
# range-specs to <dumpfile>.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/integration/kak-json.sh

plugin=$1
fixture=$2
dump=$3

work=$(mktemp -d /tmp/rmtest.XXXXXX) || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM
: >"$dump"

kak_json_start "rmtest-$$" "$work" \
  "source '$plugin'; set-option global _render_markdown_debug_file '$dump'; edit '$fixture'; _render-markdown-update"
sleep 2
kak_json_stop

if ! kak_json_error "$work"; then
  printf '%s\n' "$(cm_red "FAIL $fixture")"
  exit 1
fi
if [ ! -s "$dump" ]; then
  printf '%s\n' "$(cm_red "FAIL empty dump for $fixture")"
  exit 1
fi

printf '%s\n' "$(cm_green "ok ${fixture##*/}")"
