#!/usr/bin/env sh
# Extract the embedded classifier library (_render_markdown_sh_lib) from the
# plugin's %{...} option body.  Sourced by test/lint.sh and test/unit/run.sh.
#
# extract_sh_lib <plugin> <out>
extract_sh_lib() {
  start=$(grep -n 'declare-option -hidden str _render_markdown_sh_lib' "$1" | cut -d: -f1)
  end=$(awk -v s="$start" 'NR > s && /^  }$/ { print NR; exit }' "$1")
  sed -n "$((start + 1)),$((end - 1))p" "$1" >"$2"
}
