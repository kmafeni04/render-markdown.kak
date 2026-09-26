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
# cursor line 1 stays in source form, so only the later headings are drawn
glyphs='󰲣\|󰲥\|󰲧\|󰲩\|󰲫'
work=$(mktemp -d /tmp/rmsmoke.XXXXXX)
modework=$(mktemp -d /tmp/rmsmokemode.XXXXXX)
togglework=$(mktemp -d /tmp/rmsmoketoggle.XXXXXX)
trap 'rm -rf "$work" "$modework" "$togglework"' EXIT

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
if ! grep -q "$glyphs" "$work/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph not rendered')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok heading glyph rendered')"

# Opt-in raw view: entering insert mode removes the highlighter, so the draws
# after the mode change must not contain heading glyphs.
kak_json_start "rmsmokemode-$$" "$modework" \
  "source '$plugin'; set-option global render_markdown_raw_in_insert true; edit '$fixture'; render-markdown-enable; _render-markdown-update"
sleep 1
kak_json_key j
sleep 1
if ! grep -q "$glyphs" "$modework/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph not rendered before insert')"
  exit 1
fi
mark=$(wc -c <"$modework/out.json")
kak_json_key i # enter insert mode: the ModeChange hook drops the highlighter
sleep 1
kak_json_stop

if ! kak_json_error "$modework"; then
  printf '%s\n' "$(cm_red 'FAIL')"
  exit 1
fi
tail -c +"$((mark + 1))" "$modework/out.json" >"$modework/after.json"
if grep -q "$glyphs" "$modework/after.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph still rendered in insert mode')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok raw markdown shown in insert mode')"

# render-markdown-toggle flips rendering; render-markdown-disable throws when
# it is already off, which is exactly what the toggle's try/catch relies on.
kak_json_start "rmsmoketoggle-$$" "$togglework" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; render-markdown-toggle; try %{ render-markdown-disable } catch %{ evaluate-commands %sh{ printf 'off\\n' >> '$togglework/state' } }; render-markdown-toggle; try %{ render-markdown-disable } catch %{ evaluate-commands %sh{ printf 'still-on\\n' >> '$togglework/state' } }"
sleep 1
kak_json_stop

if ! kak_json_error "$togglework"; then
  printf '%s\n' "$(cm_red 'FAIL')"
  exit 1
fi
if ! grep -q '^off$' "$togglework/state"; then
  printf '%s\n' "$(cm_red 'FAIL toggle did not disable rendering')"
  exit 1
fi
if grep -q '^still-on$' "$togglework/state"; then
  printf '%s\n' "$(cm_red 'FAIL toggle did not re-enable rendering')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok toggle flips rendering')"
