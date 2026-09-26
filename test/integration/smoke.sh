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
statuswork=$(mktemp -d /tmp/rmsmokestatus.XXXXXX)
debugwork=$(mktemp -d /tmp/rmsmokedebug.XXXXXX)
trap 'rm -rf "$work" "$modework" "$togglework" "$statuswork" "$debugwork"' EXIT

# Start a headless session and force a redraw so the highlighter output is
# emitted.  A session that must act between the redraw and teardown (the raw
# insert check) uses start_session/stop_session directly.
start_session() { # name workdir init
  kak_json_start "rmsmoke-$1-$$" "$2" "$3"
  sleep 1
  kak_json_key j
  sleep 1
}

stop_session() { # workdir
  kak_json_stop
  if ! kak_json_error "$1"; then
    printf '%s\n' "$(cm_red 'FAIL')"
    exit 1
  fi
}

run_session() { # name workdir init
  start_session "$1" "$2" "$3"
  stop_session "$2"
}

run_session smoke "$work" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; _render-markdown-update; render-markdown-status"
if ! grep -q "$glyphs" "$work/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph not rendered')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok heading glyph rendered')"

if ! grep -q 'enabled=true' "$work/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL status did not report enabled=true while on')"
  exit 1
fi
printf '%s\n' "$(cm_green 'ok status reports enabled=true while on')"

# Raw view in insert mode is the default: entering insert removes the
# highlighter so the buffer shows raw markdown.  A mode change only emits a
# draw_status, so register a probe hook (after the plugin's raw-insert hook)
# that asks render-markdown-status whether the highlighter is installed.
start_session mode "$modework" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; hook -group rm-smoke window ModeChange 'push:.*:insert' 'render-markdown-status'; _render-markdown-update"
if ! grep -q "$glyphs" "$modework/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL heading glyph not rendered before insert')"
  exit 1
fi
mark=$(wc -c <"$modework/out.json")
kak_json_key i # enter insert mode: the ModeChange hook drops the highlighter
sleep 1
stop_session "$modework"
tail -c +"$((mark + 1))" "$modework/out.json" >"$modework/after.json"
if ! grep -q 'enabled=false' "$modework/after.json"; then
  printf '%s\n' "$(cm_red 'FAIL highlighter still installed in insert mode')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok raw markdown shown in insert mode')"

# render-markdown-toggle flips rendering; render-markdown-disable throws when
# it is already off, which is exactly what the toggle's try/catch relies on.
run_session toggle "$togglework" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; render-markdown-toggle; try %{ render-markdown-disable } catch %{ evaluate-commands %sh{ printf 'off\\n' >> '$togglework/state' } }; render-markdown-toggle; try %{ render-markdown-disable } catch %{ evaluate-commands %sh{ printf 'still-on\\n' >> '$togglework/state' } }"
if ! grep -q '^off$' "$togglework/state"; then
  printf '%s\n' "$(cm_red 'FAIL toggle did not disable rendering')"
  exit 1
fi
if grep -q '^still-on$' "$togglework/state"; then
  printf '%s\n' "$(cm_red 'FAIL toggle did not re-enable rendering')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok toggle flips rendering')"

# render-markdown-status reports the enabled state, and render-markdown-debug
# echoes the range descriptor on the cursor line.  Only the last echo is drawn
# by the json ui, so each state runs in its own session.
run_session status "$statuswork" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; render-markdown-disable; render-markdown-status"
if ! grep -q 'enabled=false' "$statuswork/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL status did not report enabled=false while off')"
  exit 1
fi
printf '%s\n' "$(cm_green 'ok status reports enabled=false while off')"

run_session debug "$debugwork" \
  "source '$plugin'; edit '$fixture'; render-markdown-enable; _render-markdown-update; render-markdown-debug"
if ! grep -q '1\.1,1\.11' "$debugwork/out.json"; then
  printf '%s\n' "$(cm_red 'FAIL debug did not list the cursor line descriptor')"
  exit 1
fi
printf '%s\n' "$(cm_green 'ok debug lists the cursor line descriptor')"
