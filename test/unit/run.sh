#!/usr/bin/env sh
# Pure-shell unit tests for the embedded classifier library
# (_render_markdown_sh_lib). Runs without Kakoune; the library is
# extracted from the plugin and exercised under dash with fake env vars.
# shellcheck disable=SC2016   # backticks/dollar-args are intentional literal content
set -eu
cd "$(dirname "$0")/../.."  # repo root
# shellcheck disable=SC1091  # color.sh is linted separately
. test/color.sh

plugin=render-markdown.kak
lib=$(mktemp /tmp/rmshlib.XXXXXX) || exit 1
trap 'rm -f "$lib"' EXIT

# extract the shell library (the %{...} option body)
start=$(grep -n 'declare-option -hidden str _render_markdown_sh_lib' "$plugin" | cut -d: -f1)
end=$(awk -v s="$start" 'NR>s && /^  }$/{print NR; exit}' "$plugin")
sed -n "$((start+1)),$((end-1))p" "$plugin" > "$lib"
[ -s "$lib" ] || { echo 'unit: could not extract shell lib'; exit 1; }
# shellcheck disable=SC1090  # lib path is a mktemp file
. "$lib"

passes=0
fails=0
pre='set-option -add window _render_markdown_bare_ranges '
check() { # name expected actual
  if [ "$2" != "$3" ]; then
    printf '%s:\n  expected: %s\n  actual:   %s\n' "$(cm_red "FAIL $1")" "$2" "$3"
    fails=$((fails+1))
  else
    printf '%s\n' "$(cm_green "ok $1")"
    passes=$((passes+1))
  fi
}

# classify <kind> with the env vars set for that case
run() {
  kind=$1
  # shellcheck disable=SC2034
  dash -c '. "$1"; render_markdown_classify "$2"' _ "$lib" "$kind"
}

kak_selection='## Two'                kak_selection_desc='2.1,2.8'
export kak_selection kak_selection_desc
export kak_opt_render_markdown_heading_1='{blue+f}G1'
export kak_opt_render_markdown_heading_2='{green+f}G2'
export kak_opt_render_markdown_checkbox_checked='{y}C '
export kak_opt_render_markdown_checkbox_unchecked='{y}U '
export kak_opt_render_markdown_bullet='{y}B '
export kak_opt_render_markdown_horizontal_rule='{r}HR'
export kak_opt_render_markdown_blockquote='{r}Q '
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
export kak_opt__render_markdown_debug_file=''
export kak_opt__render_markdown_consumed_lines=''

check 'heading level 2' \
  "${pre}'2.1,2.8|{green+f}G2 Two'
set-option -add global _render_markdown_consumed_lines 2" \
  "$(run heading)"

kak_selection='####### Too deep'       kak_selection_desc='3.1,3.19'
check 'heading >6 emits nothing' '' "$(run heading)"

kak_selection='- [x] done'             kak_selection_desc='4.1,4.10'
check 'checkbox checked' \
  "${pre}'4.1,4.10|{y}C '" \
  "$(run list)"

kak_selection='- [ ] todo'             kak_selection_desc='5.1,5.10'
check 'checkbox unchecked' \
  "${pre}'5.1,5.10|{y}U '" \
  "$(run list)"

kak_selection='* item'                 kak_selection_desc='6.1,6.7'
check 'bullet' \
  "${pre}'6.1,6.7|{y}B '" \
  "$(run list)"

kak_selection='------'                 kak_selection_desc='7.1,7.7'
check 'hrule' \
  "${pre}'7.1,7.7|{r}HR'" \
  "$(run hrule)"

kak_selection='> quote'                kak_selection_desc='8.1,8.8'
check 'blockquote' \
  "${pre}'8.1,8.8|{r}Q '" \
  "$(run blockquote)"

kak_selection='[site](https://x)'      kak_selection_desc='9.1,9.20'
check 'web link' \
  "${pre}'9.1,9.20|{b}W site'" \
  "$(run link)"

kak_selection='![img](a.png)'          kak_selection_desc='10.1,10.16'
check 'image link' \
  "${pre}'10.1,10.16|{b}I img'" \
  "$(run link)"

kak_selection='[a][b]'                 kak_selection_desc='11.1,11.7'
check 'reference link' \
  "${pre}'11.1,11.7|{b}L a'" \
  "$(run link)"

kak_selection='[a|b](x)'               kak_selection_desc='12.1,12.10'
check 'link content escapes pipe' \
  "${pre}'12.1,12.10|{b}L a\\|b'" \
  "$(run link)"

kak_selection='<u@h.c>'                kak_selection_desc='13.1,13.8'
check 'mail link' \
  "${pre}'13.1,13.8|{b}M u@h.c'" \
  "$(run link-mail)"

kak_selection='```sh'                  kak_selection_desc='14.1,14.6'
check 'codeblock start' \
  "${pre}'14.1,14.6|CB'" \
  "$(run codeblock-start)"

kak_selection='```'                    kak_selection_desc='15.1,15.4'
check 'codeblock end' \
  "${pre}'15.1,15.4|CE'" \
  "$(run codeblock-end)"

kak_selection='`code`'                 kak_selection_desc='16.1,16.7'
check 'inline code' \
  "${pre}'16.1,16.7|{c}code'" \
  "$(run inline-code)"

kak_selection='~~gone~~'               kak_selection_desc='17.1,17.9'
check 'strikethrough' \
  "${pre}'17.1,17.9|{s}gone'" \
  "$(run strike)"

kak_selection='**b**'                  kak_selection_desc='18.1,18.7'
check 'double marker -> bold face' \
  "${pre}'18.1,18.7|{B}b'" \
  "$(run emphasis)"

kak_selection='*i*'                    kak_selection_desc='19.1,19.5'
check 'single marker -> italics face' \
  "${pre}'19.1,19.5|{i}i'" \
  "$(run emphasis)"

kak_opt__render_markdown_consumed_lines='1 2'
kak_selection='*x*'                    kak_selection_desc='1.3,1.6'
check 'emphasis skipped on consumed line' '' "$(run emphasis)"

kak_selection='[x](y)'                 kak_selection_desc='2.4,2.11'
check 'link skipped on consumed line' '' "$(run link)"

kak_opt__render_markdown_consumed_lines=''

kak_selection='__u__'                  kak_selection_desc='20.1,20.7'
check 'double underscore -> bold face' \
  "${pre}'20.1,20.7|{B}u'" \
  "$(run emphasis)"

kak_selection='_u_'                    kak_selection_desc='21.1,21.5'
check 'single underscore -> italics face' \
  "${pre}'21.1,21.5|{i}u'" \
  "$(run emphasis)"

kak_selection='`c`'                    kak_selection_desc='22.1,22.5'
check 'emphasis dispatches inline code' \
  "${pre}'22.1,22.5|{c}c'" \
  "$(run emphasis)"

kak_selection="a'b"                    kak_selection_desc='23.1,23.4'
check "quote escaping a'b" \
  "${pre}'23.1,23.4|{B}a''b'" \
  "$(run em-double)"

# backslash escaping: content with a literal backslash is escaped
kak_selection='*a\b*'                  kak_selection_desc='24.1,24.6'
check 'content escapes backslash' \
  "${pre}'24.1,24.6|{i}a\\\\b'" \
  "$(run emphasis)"

# rm_inline: heading content with inline spans becomes face markup
kak_selection='' kak_selection_desc=''
export kak_opt_render_markdown_bold='{B}'
export kak_opt_render_markdown_italics='{I}'
export kak_opt_render_markdown_strikethrough='{S}'
export kak_opt_render_markdown_inline_code='{C}'
export kak_opt_render_markdown_link_link='{L}'
export kak_opt_render_markdown_link_web='{W}'
export kak_opt_render_markdown_link_image='{I}'
check 'heading plain content' 'ABC' "$(rm_inline 'ABC')"
check 'heading bold span' '{B}bold{Default}' "$(rm_inline '**bold**')"
check 'heading italic span' 'x{I}i{Default}y' "$(rm_inline 'x*i*y')"
check 'heading code span' 'a {C}c{Default} b' "$(rm_inline 'a `c` b')"
check 'heading strike span' '{S}g{Default}' "$(rm_inline '~~g~~')"
check 'heading web link' 'z{W}site{Default}' "$(rm_inline 'z[site](https://x)')"
check 'heading plain link' 'q{L}f{Default}' "$(rm_inline 'q[f](rel.md)')"
check 'heading image' '{I}img{Default}' "$(rm_inline '![img](a.png)')"
check 'heading mixed spans' 'a{B}b{Default} c{I}d{Default}' "$(rm_inline 'a**b** c*d*')"

if [ "$fails" -gt 0 ]; then
  printf '%s\n' "$(cm_red "FAIL $fails of $((passes+fails)) checks")"
  exit 1
fi
printf '%s\n' "$(cm_green "ok $passes checks")"