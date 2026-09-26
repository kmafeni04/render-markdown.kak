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
export kak_opt_indentwidth=2
export kak_opt__render_markdown_quote_starts=''
export kak_opt_render_markdown_horizontal_rule='{r}HR'
export kak_opt_render_markdown_blockquote='{r}Q '
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
export kak_opt_render_markdown_codeblock_start='CB'
export kak_opt_render_markdown_codeblock_end='CE'
export kak_opt_render_markdown_codeblock_language_icon='GEN'
export kak_opt__render_markdown_debug_file=''
export kak_opt__render_markdown_consumed_lines=''

check 'heading level 2' \
  "${pre}'2.1,2.8|{green+f}G2 Two'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run heading)"

kak_selection="## a'b" kak_selection_desc='2.1,2.6'
check 'heading content escapes a quote once' \
  "${pre}'2.1,2.6|{green+f}G2 a''b'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run heading)"

kak_selection='####### Too deep' kak_selection_desc='3.1,3.19'
check 'heading >6 emits nothing' '' "$(run heading)"

kak_selection='## Two ##' kak_selection_desc='3.1,3.9'
check 'heading strips a closing sequence' \
  "${pre}'3.1,3.9|{green+f}G2 Two'
set-option -add global _render_markdown_consumed_lines 3" \
  "$(run heading)"

kak_selection='# foo#' kak_selection_desc='4.1,4.6'
check 'heading keeps a hash with no preceding space' \
  "${pre}'4.1,4.6|{blue+f}G1 foo#'
set-option -add global _render_markdown_consumed_lines 4" \
  "$(run heading)"

kak_selection='# foo \###' kak_selection_desc='5.1,5.10'
check 'heading keeps an escaped closing run' \
  "${pre}'5.1,5.10|{blue+f}G1 foo \\\###'
set-option -add global _render_markdown_consumed_lines 5" \
  "$(run heading)"

kak_selection='- [x] done' kak_selection_desc='4.1,4.10'
check 'checkbox checked' \
  "${pre}'4.1,4.10|{y}C '" \
  "$(run list)"

kak_selection='- [ ] todo' kak_selection_desc='5.1,5.10'
check 'checkbox unchecked' \
  "${pre}'5.1,5.10|{y}U '" \
  "$(run list)"

kak_selection='- [~] n/a' kak_selection_desc='6.1,6.9'
check 'checkbox inapplicable' \
  "${pre}'6.1,6.9|{y}I '" \
  "$(run list)"

kak_selection='- [/] doing' kak_selection_desc='7.1,7.11'
check 'checkbox in progress' \
  "${pre}'7.1,7.11|{y}P '" \
  "$(run list)"

kak_selection='- [-] scrapped' kak_selection_desc='8.1,8.14'
check 'checkbox cancelled' \
  "${pre}'8.1,8.14|{y}X '" \
  "$(run list)"

kak_selection='* item' kak_selection_desc='6.1,6.7'
check 'bullet' \
  "${pre}'6.1,6.7|{y}B '" \
  "$(run list)"

kak_selection='* deep' kak_selection_desc='7.3,7.4'
check 'bullet depth 1 uses the alternate glyph' \
  "${pre}'7.3,7.4|{y}A '" \
  "$(run list)"

kak_selection='* deeper' kak_selection_desc='8.5,8.6'
check 'bullet depth 2 cycles back to the first glyph' \
  "${pre}'8.5,8.6|{y}B '" \
  "$(run list)"

kak_opt_indentwidth=4 kak_selection='* wide' kak_selection_desc='9.5,9.6'
check 'bullet depth follows indentwidth' \
  "${pre}'9.5,9.6|{y}A '" \
  "$(run list)"
kak_opt_indentwidth=2

kak_opt__render_markdown_quote_starts='11:3' kak_selection='* quoted' kak_selection_desc='11.3,11.4'
check 'bullet ignores the blockquote prefix' \
  "${pre}'11.3,11.4|{y}B '" \
  "$(run list)"

kak_opt__render_markdown_quote_starts='12:3' kak_selection='* quoted deep' kak_selection_desc='12.5,12.6'
check 'bullet depth inside a blockquote follows the list indent' \
  "${pre}'12.5,12.6|{y}A '" \
  "$(run list)"

kak_selection='1. ' kak_selection_desc='25.1,25.3'
check 'ordered marker keeps its number' \
  "${pre}'25.1,25.3|{y}1. '" \
  "$(run list)"

kak_selection='1) ' kak_selection_desc='26.1,26.3'
check 'ordered marker with a paren' \
  "${pre}'26.1,26.3|{y}1) '" \
  "$(run list)"

export kak_opt_render_markdown_bullet='G '
kak_selection='2. ' kak_selection_desc='27.1,27.3'
check 'ordered marker without a bullet face stays unfaced' \
  "${pre}'27.1,27.3|2. '" \
  "$(run list)"
export kak_opt_render_markdown_bullet='{y}B '

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

kak_selection='>' kak_selection_desc='9.1,9.1'
check 'blockquote without space' \
  "set-option -add global _render_markdown_quote_starts 9:2
${pre}'9.1,9.1|{r}Q'" \
  "$(run blockquote)"

kak_selection='>>' kak_selection_desc='10.1,10.2'
check 'blockquote nested run' \
  "set-option -add global _render_markdown_quote_starts 10:3
${pre}'10.1,10.2|{r}QQ'" \
  "$(run blockquote)"

kak_selection='[!NOTE] Title' kak_selection_desc='5.3,5.15'
check 'callout note with a title' \
  "${pre}'5.3,5.15|{n}N Title'
set-option -add global _render_markdown_consumed_lines 5" \
  "$(run callout)"

kak_selection='[!NoTe]' kak_selection_desc='6.3,6.9'
check 'callout type is case-insensitive and title optional' \
  "${pre}'6.3,6.9|{n}N'
set-option -add global _render_markdown_consumed_lines 6" \
  "$(run callout)"

kak_selection='[!tip] hi' kak_selection_desc='7.3,7.11'
check 'callout tip keeps the title separator' \
  "${pre}'7.3,7.11|{t}T hi'
set-option -add global _render_markdown_consumed_lines 7" \
  "$(run callout)"

kak_selection='[!nope] x' kak_selection_desc='8.3,8.11'
check 'unknown callout type stays literal' '' "$(run callout)"

kak_selection='[site](https://x)' kak_selection_desc='9.1,9.20'
check 'web link' \
  "${pre}'9.1,9.20|{b}W site'" \
  "$(run link)"

kak_selection='[http docs](rel.md)' kak_selection_desc='9.1,9.20'
check 'link whose label mentions http stays a relative link' \
  "${pre}'9.1,9.20|{b}L http docs'" \
  "$(run link)"

kak_selection='![img](a.png)' kak_selection_desc='10.1,10.16'
check 'image link' \
  "${pre}'10.1,10.16|{b}I img'" \
  "$(run link)"

kak_selection='[a][b]' kak_selection_desc='11.1,11.7'
check 'reference link' \
  "${pre}'11.1,11.7|{b}L a'" \
  "$(run link)"

kak_selection='[a|b](x)' kak_selection_desc='12.1,12.10'
check 'link content escapes pipe' \
  "${pre}'12.1,12.10|{b}L a\\|b'" \
  "$(run link)"

kak_selection="[a'b](x)" kak_selection_desc='12.1,12.8'
check 'link content escapes a quote once' \
  "${pre}'12.1,12.8|{b}L a''b'" \
  "$(run link)"

kak_selection='<u@h.c>' kak_selection_desc='13.1,13.8'
check 'mail link' \
  "${pre}'13.1,13.8|{b}M u@h.c'" \
  "$(run link-mail)"

kak_selection="<a'b@c.d>" kak_selection_desc='13.1,13.10'
check 'mail link content escapes a quote once' \
  "${pre}'13.1,13.10|{b}M a''b@c.d'" \
  "$(run link-mail)"

kak_selection='<https://x>' kak_selection_desc='40.1,40.11'
check 'autolink' \
  "${pre}'40.1,40.11|{b}W https://x'" \
  "$(run link-autolink)"

kak_selection='`code`' kak_selection_desc='16.1,16.6'
check 'inline code' \
  "${pre}'16.1,16.6|{c}code'" \
  "$(run emphasis)"

kak_selection='``code``' kak_selection_desc='60.1,60.8'
check 'multi-backtick code span' \
  "${pre}'60.1,60.8|{c}code'" \
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

export kak_opt_render_markdown_bold='{+b@Default}'
export kak_opt_render_markdown_italics='{+i@Default}'
kak_selection='***b***' kak_selection_desc='29.1,29.7'
check 'triple marker merges bold and italics' \
  "${pre}'29.1,29.7|{+bi@Default}b'" \
  "$(run emphasis)"
export kak_opt_render_markdown_bold='{B}'
export kak_opt_render_markdown_italics='{i}'

kak_selection='Setext one
==========' kak_selection_desc='30.1,31.10'
check 'setext heading level 1' \
  "${pre}'30.1,30.10|{blue+f}Setext one'
${pre}'31.1,31.10|'
set-option -add global _render_markdown_consumed_lines 30 31" \
  "$(run setext)"

kak_selection='Setext two
----------' kak_selection_desc='32.1,33.10'
check 'setext heading level 2' \
  "${pre}'32.1,32.10|{green+f}Setext two'
${pre}'33.1,33.10|'
set-option -add global _render_markdown_consumed_lines 32 33" \
  "$(run setext)"

kak_selection='First line
Second line
===' kak_selection_desc='34.1,36.4'
check 'multi-line setext heading faces every text line' \
  "${pre}'34.1,34.10|{blue+f}First line'
${pre}'35.1,35.11|{blue+f}Second line'
${pre}'36.1,36.3|'
set-option -add global _render_markdown_consumed_lines 34 35 36" \
  "$(run setext)"

kak_selection='  - indented item
---' kak_selection_desc='37.1,38.3'
check 'setext ignores an indented list item' '' "$(run setext)"

kak_selection='# heading interrupts
---' kak_selection_desc='39.1,40.3'
check 'setext ignores a paragraph run ending in a heading' '' "$(run setext)"

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

kak_selection='- item
---' kak_selection_desc='34.1,35.3'
check 'setext ignores a list item (the --- stays a rule)' '' "$(run setext)"

kak_selection='> quoted
---' kak_selection_desc='36.1,37.3'
check 'setext ignores a quote' '' "$(run setext)"

kak_opt__render_markdown_consumed_lines='1 2'
kak_selection='*x*' kak_selection_desc='1.3,1.6'
check 'emphasis skipped on consumed line' '' "$(run emphasis)"

kak_selection='[x](y)' kak_selection_desc='2.4,2.11'
check 'link skipped on consumed line' '' "$(run link)"

kak_selection='- - -' kak_selection_desc='2.1,2.6'
check 'list skipped on consumed line (thematic break)' '' "$(run list)"

kak_opt__render_markdown_consumed_lines=''

kak_selection='__u__' kak_selection_desc='20.1,20.5'
check 'double underscore -> bold face' \
  "${pre}'20.1,20.5|{B}u'" \
  "$(run emphasis)"

kak_selection='_u_' kak_selection_desc='21.1,21.3'
check 'single underscore -> italics face' \
  "${pre}'21.1,21.3|{i}u'" \
  "$(run emphasis)"

kak_selection='`c`' kak_selection_desc='22.1,22.3'
check 'emphasis dispatches inline code' \
  "${pre}'22.1,22.3|{c}c'" \
  "$(run emphasis)"

kak_selection="**a'b**" kak_selection_desc='23.1,23.7'
check "quote escaping a'b" \
  "${pre}'23.1,23.7|{B}a''b'" \
  "$(run emphasis)"

# backslash escaping: content with a literal backslash is escaped
kak_selection='*a\b*' kak_selection_desc='24.1,24.5'
check 'content escapes backslash' \
  "${pre}'24.1,24.5|{i}a\\\\b'" \
  "$(run emphasis)"

# the block matcher parses a whole line, so nested and mismatched runs work
export kak_opt_render_markdown_bold='{+b@Default}'
export kak_opt_render_markdown_italics='{+i@Default}'
kak_selection='*foo**bar*' kak_selection_desc='50.1,50.10'
check 'block rule of 3 leaves the inner run literal' \
  "${pre}'50.1,50.10|{+i@Default}foo**bar'" \
  "$(run emphasis)"

kak_selection='**b *i* b**' kak_selection_desc='51.1,51.11'
check 'block nesting merges the nested face' \
  "${pre}'51.1,51.11|{+b@Default}b {+bi@Default}i{+b@Default} b'" \
  "$(run emphasis)"

kak_selection='___x_' kak_selection_desc='52.1,52.5'
check 'block mismatched run keeps the surplus markers' \
  "${pre}'52.3,52.5|{+i@Default}x'" \
  "$(run emphasis)"

kak_selection='a `c` b' kak_selection_desc='53.1,53.7'
check 'block code span' \
  "${pre}'53.3,53.5|{c}c'" \
  "$(run emphasis)"
export kak_opt_render_markdown_bold='{B}'
export kak_opt_render_markdown_italics='{i}'

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
check 'heading plain content' 'ABC' "$(rm_inline 'ABC' '{H}')"
check 'heading bold span' '{H+b}bold{H}' "$(rm_inline '**bold**' '{H}')"
check 'heading italic span' 'x{H+i}i{H}y' "$(rm_inline 'x*i*y' '{H}')"
check 'heading code span' 'a {C}c{H} b' "$(rm_inline 'a `c` b' '{H}')"
check 'heading multi-backtick code span' '{C}two{H}' "$(rm_inline '``two``' '{H}')"
check 'heading strike span' '{H+s}g{H}' "$(rm_inline '~~g~~' '{H}')"
check 'heading web link' 'z{W}site{H}' "$(rm_inline 'z[site](https://x)' '{H}')"
check 'heading plain link' 'q{L}f{H}' "$(rm_inline 'q[f](rel.md)' '{H}')"
check 'heading image' '{I}img{H}' "$(rm_inline '![img](a.png)' '{H}')"
check 'heading mixed spans' 'a{H+b}b{H} c{H+i}d{H}' "$(rm_inline 'a**b** c*d*' '{H}')"
check 'heading span inherits attr token' '{blue+fb}b{blue+f}' "$(rm_inline '**b**' '{blue+f}')"
check 'heading triple marker merges bold and italics' '{H+bi}x{H}' "$(rm_inline '***x***' '{H}')"
check 'heading underscore triple marker' '{H+bi}x{H}' "$(rm_inline '___x___' '{H}')"
check 'heading nested emphasis' '{H+b}bold {H+bi}it{H+b} bold{H}' \
  "$(rm_inline '**bold *it* bold**' '{H}')"
check 'heading intraword underscore stays literal' 'a_b_c' \
  "$(rm_inline 'a_b_c' '{H}')"
check 'heading intraword asterisk emphasizes' 'a{H+i}b{H}c' \
  "$(rm_inline 'a*b*c' '{H}')"
check 'heading intraword strike emphasizes' 'a{H+s}b{H}c' \
  "$(rm_inline 'a~~b~~c' '{H}')"
check 'heading underscore span skips intraword run' '{H+i}foo_bar{H}' \
  "$(rm_inline '_foo_bar_' '{H}')"
check 'heading underscore span keeps bold run' '{H+i}a__b{H}' \
  "$(rm_inline '_a__b_' '{H}')"
check 'heading opener before space cannot close there' '*a {H+i}b{H}' \
  "$(rm_inline '*a *b*' '{H}')"
check 'heading emphasis after punctuation' 'foo.{H+i}bar{H}.' \
  "$(rm_inline 'foo.*bar*.' '{H}')"
check 'heading spec: mismatched underscore run' '__{H+i}x{H}' \
  "$(rm_inline '___x_' '{H}')"
check 'heading spec: mismatched underscore run (closing)' '{H+i}x{H}__' \
  "$(rm_inline '_x___' '{H}')"
check 'heading spec: rule of 3 leaves inner run literal' '{H+i}foo**bar{H}' \
  "$(rm_inline '*foo**bar*' '{H}')"
check 'heading spec: triple run nests' '{H+bi}x{H}' \
  "$(rm_inline '***x***' '{H}')"
check 'heading spec: nested strong inside emphasis' '{H+i}foo {H+bi}bar{H+i} baz{H}' \
  "$(rm_inline '*foo **bar** baz*' '{H}')"

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

kak_selection='| **b** |' kak_selection_desc='1.1,1.9'
check 'table cell inline emphasis keeps the cell width' \
  "${pre}'1.1+1|{P}│'
${pre}'1.9+1|{P}│'
${pre}'1.2,1.8| {+b}b{}     '
set-option -add global _render_markdown_consumed_lines 1" \
  "$(run table)"

# render_markdown_table_align: aligned table output (no trailing newline)
check 'align simple table' \
  "| a | bb | c |
|---|----|---|
| x | y  |   |" \
  "$(printf '%s\n' '| a| bb | c' '|---|---|' '| x | y' | render_markdown_table_align)"

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

check 'align columns by display width for wide glyphs' \
  "| 名前 | age |
|------|-----|
| a    | b   |" \
  "$(printf '%s\n' '| 名前 | age |' '|------|-----|' '| a | b |' | render_markdown_table_align)"

check 'rm_lang_icon uses a per-language icon' '󰢱' "$(rm_lang_icon lua)"
check 'rm_lang_icon is case-insensitive' '󰢱' "$(rm_lang_icon Lua)"
check 'rm_lang_icon falls back to the generic icon' 'GEN' "$(rm_lang_icon unknown)"

if [ "$fails" -gt 0 ]; then
  printf '%s\n' "$(cm_red "FAIL $fails of $((passes + fails)) checks")"
  exit 1
fi
printf '%s\n' "$(cm_green "ok $passes checks")"
