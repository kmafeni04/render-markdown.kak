#!/usr/bin/env sh
# Regression test: render-markdown-table-format used to drop the newline that
# ends the selected table, so a line following the table was joined onto its
# last row.
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

work=$(mktemp -d /tmp/rmformat.XXXXXX) || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM

cat >"$work/in.md" <<'EOF'
Intro.

| a | b |
|-|-|
| c | d |
text after
EOF
cat >"$work/expected.md" <<'EOF'
Intro.

| a | b |
|---|---|
| c | d |
text after
EOF

kak_json_start "rmformat-$$" "$work" \
  "source 'render-markdown.kak'; edit '$work/in.md'; execute-keys '4G'; render-markdown-table-format; write '$work/out.md'"
sleep 1
kak_json_stop

if ! kak_json_error "$work"; then
  printf '%s\n' "$(cm_red 'FAIL')"
  exit 1
fi
if ! diff -u "$work/expected.md" "$work/out.md"; then
  printf '%s\n' "$(cm_red 'FAIL table format corrupted the buffer')"
  exit 1
fi

printf '%s\n' "$(cm_green 'ok table format keeps the following line intact')"
