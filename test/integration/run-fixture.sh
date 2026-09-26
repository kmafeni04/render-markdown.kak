#!/usr/bin/env sh
# usage: run-fixture.sh <plugin> <fixture> <dumpfile> [cursor-line]
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
cursor=${4:-1}

work=$(mktemp -d /tmp/rmtest.XXXXXX) || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM
: >"$dump"

# Fixtures indent nested lists with two spaces; bullet glyphs cycle by
# indentwidth, so pin it to keep the goldens host-independent.
kak_json_start "rmtest-$$" "$work" \
  "source '$plugin'; set-option global render_markdown_margin 0; set-option global indentwidth 2; set-option global _render_markdown_debug_file '$dump'; edit '$fixture'; execute-keys '${cursor}G'; _render-markdown-update"
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
