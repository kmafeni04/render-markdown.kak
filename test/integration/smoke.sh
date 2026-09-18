#!/usr/bin/env sh
# Smoke test: verifies the replace-ranges highlighter actually draws heading
# glyphs, by inspecting the headless json ui draw events (no terminal needed).
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/integration/kak-json.sh
command -v kak >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip kak not installed')"
  exit 0
}

plugin=render-markdown.kak
fixture=test/fixtures/headings.md
work=$(mktemp -d /tmp/rmsmoke.XXXXXX) || exit 1
trap 'rm -rf "$work"' EXIT

kak_json_start "rmsmoke-$$" "$work" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; _render-markdown-update"
sleep 1
kak_json_key j # force a redraw so the highlighter output is emitted
sleep 1
kak_json_stop

if ! kak_json_error "$work"; then
  printf '%s\n' "$(cm_red 'FAIL')"
  exit 1
fi
if ! grep -q '󰲣\|󰲥\|󰲧\|󰲩\|󰲫' "$work/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph not rendered')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok heading glyph rendered')"
