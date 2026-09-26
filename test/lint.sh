#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")" || true
. ./color.sh
. ./extract-lib.sh

plugin=../render-markdown.kak

# The plugin is one Kakoune %{...} block with a shell library inside.  Kakoune
# counts braces even inside quotes, so a single unbalanced literal brace
# breaks the whole module (nothing renders at all), and a shell syntax error
# in the library breaks every render.  Check both here so the failure is named
# instead of showing up as empty fixtures.
[ -f "$plugin" ] || {
  printf '%s\n' "$(cm_red "missing $plugin")"
  exit 1
}
opens=$(tr -cd '{' <"$plugin" | wc -c)
closes=$(tr -cd '}' <"$plugin" | wc -c)
if [ "$opens" -ne "$closes" ]; then
  printf '%s\n' "$(cm_red "unbalanced braces in $plugin: $opens { against $closes }")"
  exit 1
fi

lib=$(mktemp) || exit 1
trap 'rm -f "$lib"' EXIT HUP INT TERM
extract_sh_lib "$plugin" "$lib"
dash -n "$lib" || {
  printf '%s\n' "$(cm_red 'shell syntax error in the embedded library')"
  exit 1
}
printf '%s\n' "$(cm_green 'ok plugin sanity (braces balanced, library parses)')"

command -v shellcheck >/dev/null 2>&1 || {
  printf '%s\n' "$(cm_yellow 'skip shellcheck not installed')"
  exit 0
}
find . -name '*.sh' -exec shellcheck -s dash {} + || exit 1
printf '%s\n' "$(cm_green 'ok shellcheck clean')"
