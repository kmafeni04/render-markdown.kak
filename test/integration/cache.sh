#!/usr/bin/env sh
# Verifies the render cache: render_markdown_margin makes the plugin render a
# band beyond the viewport, and a repeat update of an unchanged viewport is a
# no-op instead of re-running every matcher.
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh
# shellcheck disable=SC1091  # sourced helpers are linted separately
. test/integration/kak-json.sh
command -v kak >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip kak not installed')"
  exit 0
}

work=$(mktemp -d /tmp/rmcache.XXXXXX) || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM

# Build a 150-line buffer with bold markup on line 40 (inside the first
# screen's margin) and line 140 (only reachable after scrolling).
gen() { # file, line-40 marker, line-140 marker
  i=0
  while [ "$i" -lt 150 ]; do
    i=$((i + 1))
    case $i in
      40) printf 'line %d with **%s**\n' "$i" "$2" ;;
      140) printf 'line %d with **%s**\n' "$i" "$3" ;;
      *) printf 'line %d filler\n' "$i" ;;
    esac
  done >"$1"
}
gen "$work/in.md" bold40 bold140
# a second buffer whose first screen must not reuse in.md's cached ranges
gen "$work/other.md" boldB40 boldB140

# $1 = updates to run, $2 = run name; dumps ranges to "$work/$2.dump"
render() {
  mkdir -p "$work/$2"
  kak_json_start "rmcache-$$-$2" "$work/$2" \
    "source 'render-markdown.kak'; set-option global render_markdown_margin 24; set-option global _render_markdown_debug_file '$work/$2.dump'; edit '$work/in.md'; $1"
  sleep 1
  kak_json_stop
  kak_json_error "$work/$2" || exit 1
}

render "execute-keys '1G'; _render-markdown-update" once
render "execute-keys '1G'; _render-markdown-update; _render-markdown-update" twice
render "execute-keys '1G'; _render-markdown-update; execute-keys '120G'; _render-markdown-update" scroll
render "execute-keys '1G'; _render-markdown-update; edit '$work/other.md'; execute-keys '1G'; _render-markdown-update" switch

fail=0
grep -q '^40\.' "$work/once.dump" || { printf '%s\n' "$(cm_red 'FAIL margin did not render line 40')"; fail=1; }
if grep -q '^140\.' "$work/once.dump"; then
  printf '%s\n' "$(cm_red 'FAIL line 140 rendered without scrolling')"
  fail=1
fi
if [ "$(wc -l <"$work/once.dump")" -ne "$(wc -l <"$work/twice.dump")" ]; then
  printf '%s\n' "$(cm_red 'FAIL repeat update re-rendered the cached viewport')"
  fail=1
fi
grep -q '^140\.' "$work/scroll.dump" || { printf '%s\n' "$(cm_red 'FAIL scroll outside the margin did not re-render')"; fail=1; }
grep -q 'boldB40' "$work/switch.dump" || { printf '%s\n' "$(cm_red 'FAIL window switch reused the previous buffer cache')"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
printf '%s\n' "$(cm_green 'ok render cache reuses the margin and re-renders after scrolling')"
