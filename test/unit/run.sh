#!/usr/bin/env sh
# Pure-shell unit tests for the embedded classifier library
# (_render_markdown_sh_lib). Runs without Kakoune; the library is
# extracted from the plugin and exercised under dash with fake env vars.
# shellcheck disable=SC2016   # backticks/dollar-args are intentional literal content
set -eu
cd "$(dirname "$0")/../.." # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh
# shellcheck disable=SC1091  # extract-lib.sh is linted separately
. test/extract-lib.sh

plugin=render-markdown.kak
lib=$(mktemp /tmp/rmshlib.XXXXXX) || exit 1
trap 'rm -f "$lib"' EXIT

# extract the shell library (the %{...} option body)
extract_sh_lib "$plugin" "$lib"
[ -s "$lib" ] || {
  echo 'unit: could not extract shell lib'
  exit 1
}
# shellcheck disable=SC1090  # lib path is a mktemp file
. "$lib"

passes=0
fails=0
pre='set-option -add window _render_markdown_bare_ranges '
check() { # name expected actual
  if [ "$2" != "$3" ]; then
    printf '%s:\n  expected: %s\n  actual:   %s\n' "$(cm_red "FAIL $1")" "$2" "$3"
    fails=$((fails + 1))
  else
    printf '%s\n' "$(cm_green "ok $1")"
    passes=$((passes + 1))
  fi
}

# classify <kind> with the env vars set for that case
run() {
  kind=$1
  # shellcheck disable=SC2034
  dash -c '. "$1"; render_markdown_classify "$2"' _ "$lib" "$kind"
}

kak_selection='## Two' kak_selection_desc='2.1,2.8'
export kak_selection kak_selection_desc
export kak_opt_render_markdown_heading_1='{blue+f}G1'
export kak_opt_render_markdown_heading_2='{green+f}G2'
export kak_opt_render_markdown_checkbox_checked='{y}C '
export kak_opt_render_markdown_checkbox_unchecked='{y}U '
export kak_opt_render_markdown_checkbox_inapplicable='{y}I '
export kak_opt_render_markdown_checkbox_in_progress='{y}P '
export kak_opt_render_markdown_checkbox_cancelled='{y}X '
export kak_opt_render_markdown_bullet='{y}B '
export kak_opt_render_markdown_bullet_alt='{y}A '
export kak_opt__render_markdown_bullet_head='{y}'
export kak_opt_indentwidth=2
export kak_opt__render_markdown_quote_starts=''
export kak_opt_render_markdown_horizontal_rule='{r}HR'
export kak_opt_render_markdown_blockquote='{r}Q '
export kak_opt__render_markdown_quote_head='{r}'
export kak_opt__render_markdown_quote_glyph='Q'
export kak_opt_render_markdown_callout_note='{n}N'
export kak_opt_render_markdown_callout_tip='{t}T'
export kak_opt_render_markdown_callout_important='{m}M'
export kak_opt_render_markdown_callout_warning='{w}W'
export kak_opt_render_markdown_callout_caution='{c}C'
export kak_opt_render_markdown_link_image='{b}I '
export kak_opt_render_markdown_link_web='{b}W '
export kak_opt_render_markdown_link_link='{b}L '
export kak_opt_render_markdown_link_mail='{b}M '
export kak_opt_render_markdown_strikethrough='{s}'
export kak_opt_render_markdown_italics='{i}'
export kak_opt_render_markdown_bold='{B}'
export kak_opt_render_markdown_inline_code='{c}'
export kak_opt_render_markdown_codeblock_end='CE'
export kak_opt_render_markdown_codeblock_language_icon='GEN'
export kak_opt__render_markdown_debug_file=''
export kak_opt__render_markdown_consumed_lines=''

# One option-plumbing canary per kind: the fixture goldens all run with the
# default option values, so a classifier that ignored a custom option would
# still pass them.  The other cases are the ones no fixture covers.
check 'heading level 2' \
  "${pre}'2.1,2.8|{green+f}G2 Two'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run heading)"

kak_selection="## a'b" kak_selection_desc='2.1,2.6'
check 'heading content escapes a quote once' \
  "${pre}'2.1,2.6|{green+f}G2 a''b'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run heading)"

kak_selection='- [x] done' kak_selection_desc='4.1,4.10'
check 'checkbox checked' \
  "${pre}'4.1,4.10|{y}C '" \
  "$(run list)"

kak_selection='* deep' kak_selection_desc='7.3,7.4'
check 'bullet depth 1 uses the alternate glyph' \
  "${pre}'7.3,7.4|{y}A '" \
  "$(run list)"

kak_opt_indentwidth=4 kak_selection='* wide' kak_selection_desc='9.5,9.6'
check 'bullet depth follows indentwidth' \
  "${pre}'9.5,9.6|{y}A '" \
  "$(run list)"
kak_opt_indentwidth=2

kak_selection='1. ' kak_selection_desc='25.1,25.3'
check 'ordered marker keeps its number' \
  "${pre}'25.1,25.3|{y}1. '" \
  "$(run list)"

export kak_opt_render_markdown_bullet='G '
export kak_opt__render_markdown_bullet_head=''
kak_selection='2. ' kak_selection_desc='27.1,27.3'
check 'ordered marker without a bullet face stays unfaced' \
  "${pre}'27.1,27.3|2. '" \
  "$(run list)"
export kak_opt_render_markdown_bullet='{y}B '
export kak_opt__render_markdown_bullet_head='{y}'

kak_selection='------' kak_selection_desc='7.1,7.7'
check 'hrule' \
  "${pre}'7.1,7.7|{r}HR'
set-option -add global _render_markdown_consumed_lines 7" \
  "$(run hrule)"

kak_selection='> ' kak_selection_desc='8.1,8.2'
check 'blockquote' \
  "set-option -add global _render_markdown_quote_starts 8:3
${pre}'8.1,8.2|{r}Q '" \
  "$(run blockquote)"

kak_selection='[!NOTE] Title' kak_selection_desc='5.3,5.15'
check 'callout note with a title' \
  "${pre}'5.3,5.15|{n}N Title'
set-option -add global _render_markdown_consumed_lines 5" \
  "$(run callout)"

kak_selection='[site](https://x)' kak_selection_desc='9.1,9.20'
check 'web link' \
  "${pre}'9.1,9.20|{b}W site'
set-option -add global _render_markdown_link_spans '9.1,9.20'" \
  "$(run link)"

kak_selection='[http docs](rel.md)' kak_selection_desc='9.1,9.20'
check 'link whose label mentions http stays a relative link' \
  "${pre}'9.1,9.20|{b}L http docs'
set-option -add global _render_markdown_link_spans '9.1,9.20'" \
  "$(run link)"

kak_selection='[`code`](rel.md)' kak_selection_desc='9.1,9.20'
check 'link label renders inline code' \
  "${pre}'9.1,9.20|{b}L {c}code{b}'
set-option -add global _render_markdown_link_spans '9.1,9.20'" \
  "$(run link)"

kak_selection='`code`' kak_selection_desc='16.1,16.6'
check 'inline code' \
  "${pre}'16.1,16.6|{c}code'" \
  "$(run emphasis)"

kak_selection='~~gone~~' kak_selection_desc='17.1,17.8'
check 'strikethrough' \
  "${pre}'17.1,17.8|{s}gone'" \
  "$(run emphasis)"

kak_selection='**b**' kak_selection_desc='18.1,18.5'
check 'double marker -> bold face' \
  "${pre}'18.1,18.5|{B}b'" \
  "$(run emphasis)"

kak_selection='*i*' kak_selection_desc='19.1,19.3'
check 'single marker -> italics face' \
  "${pre}'19.1,19.3|{i}i'" \
  "$(run emphasis)"

kak_selection='___x___' kak_selection_desc='28.1,28.7'
check 'triple marker falls back to the bold face' \
  "${pre}'28.1,28.7|{B}x'" \
  "$(run emphasis)"

kak_selection='Setext one
==========' kak_selection_desc='30.1,31.10'
check 'setext heading level 1' \
  "${pre}'30.1,30.10|{blue+f}G1 Setext one'
${pre}'31.1,31.10|'
set-option -add global _render_markdown_consumed_lines 30 31" \
  "$(run setext)"

kak_selection='body text
# heading
---' kak_selection_desc='41.1,43.3'
check 'setext stops at a heading inside the paragraph' '' "$(run setext)"

kak_selection='---
title: x
---
' kak_selection_desc='1.1,3.4'
check 'front matter hidden and consumed' \
  "${pre}'1.1,1.3|'
${pre}'2.1,2.8|'
${pre}'3.1,3.3|'
set-option -add global _render_markdown_consumed_lines 1 2 3" \
  "$(run front-matter)"

kak_selection='---
title: x
---
' kak_selection_desc='5.1,7.4'
check 'front matter away from line 1 is ignored' '' "$(run front-matter)"

kak_selection='<!-- c -->' kak_selection_desc='6.1,6.10'
check 'comment concealed and consumed' \
  "${pre}'6.1,6.10|'
set-option -add global _render_markdown_consumed_lines 6" \
  "$(run comment)"

kak_opt__render_markdown_consumed_lines='1 2'
kak_selection='*x*' kak_selection_desc='1.3,1.6'
check 'emphasis skipped on consumed line' '' "$(run emphasis)"

kak_selection='[x](y)' kak_selection_desc='2.4,2.11'
check 'link skipped on consumed line' '' "$(run link)"

kak_opt__render_markdown_consumed_lines=''

# backslash escaping: content with a literal backslash is escaped
kak_selection='*a\b*' kak_selection_desc='24.1,24.5'
check 'content escapes backslash' \
  "${pre}'24.1,24.5|{i}a\\\\b'" \
  "$(run emphasis)"

# CommonMark converts line endings to spaces before its one-space strip: an
# all-space crossing span keeps them, and an edge line ending is stripped like
# a space.  The padding is built from a variable so the source keeps no
# trailing whitespace.
pad='  '
kak_selection="\`$pad
$pad\`"
kak_selection_desc='1.1,2.3'
check 'crossing all-space code span keeps its padding' \
  "${pre}'1.1,1.3|{c}  '
${pre}'2.3,2.3|{c}'" \
  "$(run emphasis)"

kak_selection='`
 code `'
kak_selection_desc='1.1,2.7'
check 'crossing code span treats a line ending as a space' \
  "${pre}'1.1,1.1|{c}'
${pre}'2.2,2.7|{c}code'" \
  "$(run emphasis)"

# rm_inline: heading content with inline spans becomes face markup that
# inherits the heading face (base) and resets back to it
kak_selection='' kak_selection_desc=''
export kak_opt_render_markdown_bold='{B}'
export kak_opt_render_markdown_italics='{I}'
export kak_opt_render_markdown_strikethrough='{S}'
export kak_opt_render_markdown_inline_code='{C}'
export kak_opt_render_markdown_link_link='{L}'
export kak_opt_render_markdown_link_web='{W}'
export kak_opt_render_markdown_link_image='{I}'
check 'heading bold span' '{H+b}bold{H}' "$(rm_inline '**bold**' '{H}')"
check 'heading code span' 'a {C}c{H} b' "$(rm_inline 'a `c` b' '{H}')"
check 'heading strike span' '{H+s}g{H}' "$(rm_inline '~~g~~' '{H}')"
check 'heading web link' 'z{W}site{H}' "$(rm_inline 'z[site](https://x)' '{H}')"
check 'heading image' '{I}img{H}' "$(rm_inline '![img](a.png)' '{H}')"
check 'heading code in a link label' '{W}{C}code{W}{H}' \
  "$(rm_inline '[`code`](https://x)' '{H}')"
check 'heading emphasis in a link label' '{W}{W+b}b{W}{H}' \
  "$(rm_inline '[**b**](https://x)' '{H}')"
check 'heading mixed spans' 'a{H+b}b{H} c{H+i}d{H}' "$(rm_inline 'a**b** c*d*' '{H}')"
check 'heading triple marker merges bold and italics' '{H+bi}x{H}' "$(rm_inline '***x***' '{H}')"
check 'heading intraword strike emphasizes' 'a{H+s}b{H}c' \
  "$(rm_inline 'a~~b~~c' '{H}')"

export kak_opt_render_markdown_table_separator='{S}'
export kak_opt_render_markdown_table_pipe='{P}'

kak_selection='|---|---|' kak_selection_desc='2.1,2.10'
check 'table separator row' \
  "${pre}'2.1,2.10|{S}├───┼───┤'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run table)"

kak_selection='| a | b |' kak_selection_desc='1.1,1.9'
check 'table pipe bars' \
  "${pre}'1.1+1|{P}│'
${pre}'1.5+1|{P}│'
${pre}'1.9+1|{P}│'
set-option -add global _render_markdown_consumed_lines 1" \
  "$(run table)"

kak_selection='| é | b |' kak_selection_desc='1.1,1.10'
check 'table pipe bars after a multi-byte cell' \
  "${pre}'1.1+1|{P}│'
${pre}'1.6+1|{P}│'
${pre}'1.10+1|{P}│'
set-option -add global _render_markdown_consumed_lines 1" \
  "$(run table)"

# render_markdown_table_align: aligned table output (no trailing newline)
check 'align keeps indent and pads uneven rows' \
  "  | a       | bb  | c | new |
  |---------|-----|---|-----|
  | aaa     | bbb |   |     |
  | new row |     |   |     |" \
  "$(printf '%s\n' '  | a | bb | c | new' '  |---|---|' '  | aaa | bbb |' '  | new row' | render_markdown_table_align)"

check 'align separator min three dashes' \
  "| c  |
|----|
| xx |" \
  "$(printf '%s\n' '| c' '|-' '| xx' | render_markdown_table_align)"

check 'rm_width counts wide and zero-width characters' \
  '3 6 2 4 1' \
  "$(rm_width abc) $(rm_width 日本語) $(rm_width 😀) $(rm_width a日b) $(rm_width "e$(printf '\314\201')")"

check 'rm_escape escapes an opening brace and backslashes' \
  '\{a}\\b' "$(rm_escape '{a}\b' "$OB")"

check 'rm_strip_markup strips face markup and undoes brace escapes' \
  ' type Name = {K: V} ' \
  "$(rm_strip_markup ' {cyan}type Name = \{K: V}{} ')"

check 'rm_strip_markup collapses a doubled backslash' \
  'a\b' "$(rm_strip_markup '{cyan}a\\b{}')"

check 'align columns by display width for wide glyphs' \
  "| 名前 | age |
|------|-----|
| a    | b   |" \
  "$(printf '%s\n' '| 名前 | age |' '|------|-----|' '| a | b |' | render_markdown_table_align)"

check 'rm_lang_icon is case-insensitive' '󰢱' "$(rm_lang_icon Lua)"
check 'rm_lang_icon falls back to the generic icon' 'GEN' "$(rm_lang_icon unknown)"

check 'rm_marker_glyph on a plain marker' 'plain' "$(rm_marker_glyph plain)"

check 'rm_status reports the window state' \
  'render-markdown: enabled=true buffer=example.md (42 lines) band=1-30 timestamp=9' \
  "$(kak_opt__render_markdown_buf=example.md kak_opt__render_markdown_lines=42 \
    kak_opt__render_markdown_cache='7 1 30' kak_opt__render_markdown_ts=9 \
    rm_status true)"

if [ "$fails" -gt 0 ]; then
  printf '%s\n' "$(cm_red "FAIL $fails of $((passes + fails)) checks")"
  exit 1
fi
printf '%s\n' "$(cm_green "ok $passes checks")"
