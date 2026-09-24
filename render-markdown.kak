provide-module render-markdown %{

  declare-option -hidden str-list _render_markdown_bare_ranges
  declare-option -hidden range-specs _render_markdown_ranges
  declare-option -hidden str _render_markdown_kind ''
  declare-option -hidden str-list _render_markdown_consumed_lines ''
  declare-option -hidden str-list _render_markdown_fence_spans ''
  declare-option -hidden str-list _render_markdown_fence_starts ''
  declare-option -hidden str-list _render_markdown_fence_ends ''

  declare-option str render_markdown_heading_1 "{blue+f}󰲡"
  declare-option str render_markdown_heading_2 "{green+f} 󰲣"
  declare-option str render_markdown_heading_3 "{yellow+f}  󰲥"
  declare-option str render_markdown_heading_4 "{cyan+f}   󰲧"
  declare-option str render_markdown_heading_5 "{magenta+f}    󰲩"
  declare-option str render_markdown_heading_6 "{red+f}     󰲫"

  declare-option str render_markdown_codeblock_start " "
  declare-option str render_markdown_codeblock_end " "

  declare-option str render_markdown_checkbox_checked "{yellow+f}󰱒 "
  declare-option str render_markdown_checkbox_unchecked "{yellow+f}󰄱 "

  declare-option str render_markdown_bullet "{yellow+f} "

  declare-option str render_markdown_horizontal_rule "{rgb:3e3e3e+f}──────────────────"

  declare-option str render_markdown_blockquote "{rgb:3e3e3e+f}▋ "

  declare-option str render_markdown_link_image "{blue+fu@Default} "
  declare-option str render_markdown_link_web "{blue+fu@Default}󰖟 "
  declare-option str render_markdown_link_link "{blue+fu@Default} "
  declare-option str render_markdown_link_mail "{blue+fu@Default}󰇮 "

  declare-option str render_markdown_strikethrough "{+s@Default}"
  declare-option str render_markdown_italics "{+i@Default}"
  declare-option str render_markdown_bold "{+b@Default}"
  declare-option str render_markdown_inline_code "{cyan,rgb:3e3e3e+f}"

  declare-option str render_markdown_table_separator "{rgb:3e3e3e+f}"
  declare-option str render_markdown_table_pipe "{rgb:3e3e3e+f}"

  # Test-only: when set to a file path, every emitted range is also appended
  # verbatim (one per line). Used by test/integration/run-fixture.sh to build
  # and check golden files; unset (default) means no extra runtime work.
  declare-option -hidden str _render_markdown_debug_file ''

  # begin-sh-lib
  # Embedded POSIX shell library (dash-verified), eval'd from the %sh blocks
  # below. NOTE: braces must stay balanced because Kakoune tracks them in
  # %{...} strings.
  declare-option -hidden str _render_markdown_sh_lib %{
    # kakoune single-quote escaping: ' becomes ''
    # Fork-free: these run once per emitted range, and forking sed in them
    # dominated rendering time on code-block-heavy buffers.
    rm_quote() {
      s=$1
      out=
      while [ -n "$s" ]; do
        c=${s%"${s#?}"} # first character of $s
        s=${s#?}
        case "$c" in
          "'") out="$out''" ;;
          *) out="$out$c" ;;
        esac
      done
      printf '%s' "$out"
    }
    # emit a bare range: <desc>|<face><text>, + debug-file mirror. The
    # face/text part is escaped per the range-specs format (| and \);
    # rm_emit_desc takes an explicit descriptor for per-position ranges.
    rm_emit() {
      rm_emit_desc "$kak_selection_desc" "$2" "$3"
    }

    rm_emit_desc() {
      range="$1|$(rm_escape "$2$3")"
      printf "set-option -add window _render_markdown_bare_ranges '%s'\n" "$(rm_quote "$range")"
      if [ -n "$kak_opt__render_markdown_debug_file" ]; then
        printf '%s\n' "$range" >> "$kak_opt__render_markdown_debug_file"
      fi
    }

    rm_strip() {
      printf '%s' "$1" | tr -d "$2"
    }

    rm_escape() {
      s=$1
      out=
      while [ -n "$s" ]; do
        c=${s%"${s#?}"} # first character of $s
        s=${s#?}
        case "$c" in
          \\) out="$out\\\\" ;;
          '|') out="$out\\|" ;;
          *) out="$out$c" ;;
        esac
      done
      printf '%s' "$out"
    }

    # start line of the current selection descriptor (a.b,c.d -> a)
    rm_line() {
      printf '%s' "$kak_selection_desc" | sed 's/\..*//'
    }

    # true when the current selection's line is heading-consumed
    rm_consumed() {
      case " $kak_opt__render_markdown_consumed_lines " in
        *" $(rm_line) "*) return 0 ;;
        *) return 1 ;;
      esac
    }

    # face markup from a face option like {blue+f}󰲡 -> {blue+f}; the close
    # brace is built via octal so no brace literal appears in this block
    rm_head() {
      cb=$(printf '\175')
      case "$1" in
        *"$cb"*) printf '%s' "${1%%$cb*}$cb" ;;
        *) printf '' ;;
      esac
    }

    # ***text*** is bold and italics: merge the two face specs when both are
    # plain attribute specs ({+b@Default} and {+i@Default} become {+bi@Default}),
    # otherwise keep the bold face.  ob and cb are the brace characters.
    rm_merge_triple() { # $1 = bold face, $2 = italics face
      ob=$(printf '\173')
      cb=$(printf '\175')
      bold=${1#$ob}
      bold=${bold%$cb}
      italics=${2#$ob}
      italics=${italics%$cb}
      case "$bold/$italics" in
        +*@*/+*@*)
          bold_attrs=${bold#+}
          bold_attrs=${bold_attrs%%@*}
          italic_attrs=${italics#+}
          italic_attrs=${italic_attrs%%@*}
          printf '%s' "$ob+$bold_attrs$italic_attrs@${bold#*@}$cb" ;;
        +*/+*) printf '%s' "$ob${bold#+}${italics#+}$cb" ;;
        *) printf '%s' "$1" ;;
      esac
    }

    # earliest span delimiter in $s, or empty
    rm_next_delim() {
      best=9999
      found=
      for tok in '`' '**' '__' '~~' '![' '[' '_' '*'; do
        case "$s" in
          *"$tok"*)
            front=${s%%"$tok"*}
            pos=${#front}
            if [ "$pos" -lt "$best" ]; then best=$pos; found=$tok; fi
            ;;
        esac
      done
      printf '%s' "$found"
    }

    # render inline markdown spans in heading content as face markup: a span
    # adds its attribute to the inherited base face and resets to it, so the
    # whole heading keeps one color (links/code keep their faces). Single
    # level, no nesting; unrecognised text passes through.
    rm_inline() {
      s=$1
      base=$2
      inside=${base#?}
      inside=${inside%?}
      out=
      while [ -n "$s" ]; do
        d=$(rm_next_delim)
        if [ -z "$d" ]; then
          out="$out$s"
          break
        fi
        front=${s%%"$d"*}
        out="$out$front"
        s=${s#"$front"}
        s=${s#"$d"}
        case "$d" in
          '`')
            case "$s" in
              *\`*)
                inner=${s%%\`*}
                out="$out$kak_opt_render_markdown_inline_code$inner$base"
                s=${s#*"$inner"\`} ;;
              *) out="$out\`$s"; s= ;;
            esac ;;
          '**'|'__'|'~~'|'*'|'_')
            case "$d" in
              '**'|'__') attr=b ;;
              '~~')      attr=s ;;
              '*'|'_')   attr=i ;;
            esac
            case "$s" in
              *"$d"*)
                inner=${s%%"$d"*}
                # merge the attribute into the base's attribute token:
                # {blue+f} + b -> {blue+fb}, {blue} + b -> {blue+b}
                case "$inside" in
                  *+*) span="{${inside%+*}+${inside##*+}$attr}" ;;
                  *)   span="{${inside}+$attr}" ;;
                esac
                out="$out$span$inner$base"
                s=${s#*"$inner""$d"} ;;
              *) out="$out$d$s"; s= ;;
            esac ;;
          '![')
            case "$s" in
              *\]*)
                label=${s%%\]*}
                out="$out$kak_opt_render_markdown_link_image$label$base"
                s=${s#*"$label"]}
                # drop the (url) part
                case "$s" in
                  \(*\)) s=${s#\(}; s=${s#*\)} ;;
                esac ;;
            esac ;;
          '[')
            case "$s" in
              *\]\(*)
                label=${s%%\]*}
                rest=${s#*"$label"]}
                case "$rest" in
                  \(*\))
                    url=${rest#\(}; url=${url%%\)*}
                    case "$url" in
                      *http*) out="$out$kak_opt_render_markdown_link_web$label$base" ;;
                      *)      out="$out$kak_opt_render_markdown_link_link$label$base" ;;
                    esac
                    s=${rest#\("$url"\)} ;;
                  *) out="$out[$label$rest"; s= ;;
                esac ;;
              *) out="$out[$s"; s= ;;
            esac ;;
        esac
      done
      printf '%s' "$out"
    }

render_markdown_table_align() {
  # read rows from stdin, remember the first line's indent
  n=0
  indent=
  while IFS= read -r line; do
    n=$((n + 1))
    eval "row$n=\$line"
    if [ -z "$indent" ]; then
      indent=$(printf '%s' "$line" | sed 's/[^[:space:]].*//')
    fi
  done
  rows=$n

  # pass 1: split into trimmed segments, detect separator rows, and record
  # the per-column content width (separators do not count towards widths)
  maxcols=0
  i=0
  while [ $i -lt "$rows" ]; do
    i=$((i + 1))
    eval "line=\$row$i"
    rest=$line
    j=0
    while :; do
      case "$rest" in
        *\|*) seg=${rest%%\|*}; rest=${rest#*\|} ;;
        *)    seg=$rest;        rest= ;;
      esac
      j=$((j + 1))
      seg=$(printf '%s' "$seg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      eval "s${i}_${j}=\$seg"
      [ -n "$rest" ] || break
    done

    # columns = segments after the leading pipe, up to the last non-empty one
    last=$j
    while [ "$last" -gt 1 ] && eval "[ -z \"\$s${i}_${last}\" ]"; do
      last=$((last - 1))
    done
    cols=$((last - 1))
    [ "$cols" -gt 0 ] || cols=0

    # separator row: every segment is empty or dash/colon, with a dash
    hasdash=0; sep=1
    k=1
    while [ $k -le "$j" ]; do
      eval "seg=\$s${i}_${k}"
      case "$seg" in
        '') ;;
        *[!-:]*) sep=0 ;;
        *-*) hasdash=1 ;;
      esac
      k=$((k + 1))
    done
    [ "$hasdash" -eq 0 ] && sep=0
    eval "sep$i=$sep"
    eval "segn$i=$j"

    if [ "$sep" -eq 0 ]; then
      k=2
      while [ $k -le "$j" ]; do
        eval "seg=\$s${i}_${k}"
        len=${#seg}
        col=$((k - 1))
        w=$(eval "printf '%s' \"\${w$col:-}\"")
        [ -z "$w" ] && w=0
        [ "$len" -gt "$w" ] && eval "w$col=$len"
        k=$((k + 1))
      done
    fi
    [ "$cols" -gt "$maxcols" ] && maxcols=$cols
  done

  # pass 2: emit the aligned rows
  i=0
  while [ $i -lt "$rows" ]; do
    i=$((i + 1))
    eval "sep=\$sep$i"
    if [ "$sep" -eq 1 ]; then
      line="$indent|"
      k=1
      while [ $k -le "$maxcols" ]; do
        w=$(eval "printf '%s' \"\${w$k:-}\"")
        [ -z "$w" ] && w=0
        d=$((w + 2)); [ "$d" -lt 3 ] && d=3
        dashes=$(printf '%0*d' "$d" 0 | tr '0' '-')
        line="$line$dashes|"
        k=$((k + 1))
      done
    else
      line="$indent|"
      k=1
      while [ $k -le "$maxcols" ]; do
        pos=$((k + 1))
        eval "segn=\$segn$i"
        if [ "$pos" -le "$segn" ]; then
          eval "cell=\$s${i}_${pos}"
        else
          cell=
        fi
        w=$(eval "printf '%s' \"\${w$k:-}\"")
        [ -z "$w" ] && w=0
        nsp=$((w - ${#cell}))
        pad=$(printf '%*s' "$nsp" '')
        line="$line $cell$pad |"
        k=$((k + 1))
      done
    fi
    if [ "$i" -lt "$rows" ]; then
      printf '%s\n' "$line"
    else
      printf '%s' "$line"
    fi
  done
}
    render_markdown_classify() {
      kind=$1
      case "$kind" in
        heading)
          level=$(printf '%s' "$kak_selection" | grep -o '^#*' | wc -c)
          level=$((level - 1))
          if [ "$level" -gt 6 ]; then exit 0; fi
          eval "face=\$kak_opt_render_markdown_heading_$level"
          content=$(printf '%s' "$kak_selection" | sed -e 's/^#*//' -e "s/'/''/g")
          rm_emit heading "$face" "$(rm_inline "$content" "$(rm_head "$face")")"
          # the whole heading line is consumed; inline kinds must not match inside it
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$(rm_line)" ;;
        setext)
          # face the text line, hide the underline, consume both
          if rm_consumed; then exit 0; fi
          case "$kak_selection" in
            \>*|[-*+]\ *|[0-9]*.\ *|[0-9]*\)\ *)
              # a list item or quote is not a paragraph, so "---" stays a rule
              exit 0 ;;
          esac
          nl=$(printf '\n_')  # nl is a newline, to split the two lines apart
          nl=${nl%_}
          text=${kak_selection%%"$nl"*}
          underline=${kak_selection#*"$nl"}
          underline=${underline%$nl}
          case "$underline" in
            =*) face=$kak_opt_render_markdown_heading_1 ;;
            *) face=$kak_opt_render_markdown_heading_2 ;;
          esac
          face=$(rm_head "$face")  # no marker to replace, so no glyph either
          line=${kak_selection_desc%%.*}
          rm_emit_desc "$line.1,$line.${#text}" "$face" "$(rm_inline "$text" "$face")"
          rm_emit_desc "$((line + 1)).1,$((line + 1)).${#underline}" ''
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$line" "$((line + 1))" ;;
        list)
          if rm_consumed; then exit 0; fi
          content=
          case "$kak_selection" in
            -*\[x\]*) face=$kak_opt_render_markdown_checkbox_checked ;;
            -*\[*\]*) face=$kak_opt_render_markdown_checkbox_unchecked ;;
            [0-9]*)
              # an ordered marker is content, so it keeps its number.  Reuse
              # the bullet's face when it has one, so both kinds look alike
              # (a glyph-only bullet setting leaves the marker unfaced).
              face=$(rm_head "$kak_opt_render_markdown_bullet")
              content=$kak_selection
              ;;
            *) face=$kak_opt_render_markdown_bullet ;;
          esac
          rm_emit list "$face" "$content" ;;
        hrule)
          if rm_consumed; then exit 0; fi
          rm_emit hrule "$kak_opt_render_markdown_horizontal_rule" ''
          # the rule line is consumed: emphasis markers inside it must not match
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$(rm_line)" ;;
        blockquote)
          # replace the leading '>' run with one glyph per '>' (whitespace is
          # kept): '> ' -> '▋ ', '>text' -> '▋text', '>> t' -> '▋▋ t'
          cb=$(printf '\175')  # close-brace char, so no brace literal appears here
          head=$(printf '%s' "$kak_opt_render_markdown_blockquote" | sed "s/$cb.*/$cb/")
          glyph=$(printf '%s' "$kak_opt_render_markdown_blockquote" | sed "s/.*$cb//;s/[[:space:]]*$//")
          s=$kak_selection
          drawn=
          while [ -n "$s" ]; do
            c=$(printf '%.1s' "$s")
            s=${s#?}
            case "$c" in
              '>') drawn="$drawn$glyph" ;;
              *) drawn="$drawn$c" ;;
            esac
          done
          rm_emit blockquote "$head" "$drawn" ;;
        table)
          # rows are consumed so inline kinds never render inside cells.
          # Separator rows (only dashes/colons between pipes) are redrawn as a
          # connecting grid line, e.g. |---|----| -> ├────┼──┤; other rows get
          # each pipe replaced by a box-drawing bar (│). All replacement
          # glyphs are single-width, so column alignment is never disturbed.
          pos=${kak_selection_desc%%,*}
          line=${pos%%.*}
          col=${pos#*.}
          content=$(printf '%s' "$kak_selection" | tr -d ' \t|')
          if [ -n "$content" ] && ! printf '%s' "$content" | grep -q '[^-:]'; then
            pipes=$(printf '%s' "$kak_selection" | tr -cd '|' | wc -c)
            s=$kak_selection
            drawn=
            n=0
            while [ -n "$s" ]; do
              c=$(printf '%.1s' "$s")
              s=${s#?}
              case "$c" in
                '|')
                  n=$((n + 1))
                  if [ "$n" -eq 1 ]; then c='├'
                  elif [ "$n" -eq "$pipes" ]; then c='┤'
                  else c='┼'; fi ;;
                '-'|':') c='─' ;;
              esac
              drawn="$drawn$c"
            done
            rm_emit table "$kak_opt_render_markdown_table_separator" "$drawn"
          else
            s=$kak_selection
            off=$col
            while [ -n "$s" ]; do
              case "$s" in
                \|*) rm_emit_desc "$line.$off+1" "$kak_opt_render_markdown_table_pipe" '│' ;;
              esac
              s=${s#?}
              off=$((off + 1))
            done
          fi
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$line" ;;
        link)
          if rm_consumed; then exit 0; fi
          content=$(printf '%s' "$kak_selection" | sed -e 's/^!//' -e 's/^\[//' -e 's/\]\(.*\)$//' -e 's/\]\[.*$//' -e "s/'/''/g")
          case "$kak_selection" in
            !*)    face=$kak_opt_render_markdown_link_image ;;
            *http*) face=$kak_opt_render_markdown_link_web ;;
            *)     face=$kak_opt_render_markdown_link_link ;;
          esac
          rm_emit link "$face" "$content" ;;
        link-mail)
          if rm_consumed; then exit 0; fi
          content=$(printf '%s' "$kak_selection" | sed -e 's/^<//' -e 's/>$//' -e "s/'/''/g")
          rm_emit link "$kak_opt_render_markdown_link_mail" "$content" ;;
        inline-code)
          rm_emit code "$kak_opt_render_markdown_inline_code" "$(rm_strip "$kak_selection" '`')" ;;
        strike)
          rm_emit strike "$kak_opt_render_markdown_strikethrough" "$(rm_strip "$kak_selection" '~')" ;;
        emphasis)
          if rm_consumed; then exit 0; fi
          # dispatch by first marker char: ~ strike, ` inline code, _/* em
          start=$(printf '%.1s' "$kak_selection")
          case "$start" in
            '~') render_markdown_classify strike ;;
            '`') render_markdown_classify inline-code ;;
            '*'|'_')
              case "$kak_selection" in
                # longest run first: "__*" also matches "___"
                ___*|\*\*\**) render_markdown_classify em-triple ;;
                __*|\*\**) render_markdown_classify em-double ;;
                *) render_markdown_classify em-single ;;
              esac
              ;;
          esac
          ;;
        em-triple)
          # ***x*** / ___x___ -> bold and italics together
          face=$(rm_merge_triple "$kak_opt_render_markdown_bold" "$kak_opt_render_markdown_italics")
          case "$kak_selection" in
            ___*) content=$(rm_strip "$kak_selection" '_') ;;
            *)    content=$(rm_strip "$kak_selection" '*') ;;
          esac
          rm_emit em "$face" "$content" ;;
        em-double)
          # **x** / __x__ -> bold face (markdown semantics)
          case "$kak_selection" in
            __*) face=$kak_opt_render_markdown_bold; content=$(rm_strip "$kak_selection" '_') ;;
            *)   face=$kak_opt_render_markdown_bold; content=$(rm_strip "$kak_selection" '*') ;;
          esac
          rm_emit em "$face" "$content" ;;
        em-single)
          # *x* / _x_ -> italics face (markdown semantics)
          case "$kak_selection" in
            _*) face=$kak_opt_render_markdown_italics; content=$(rm_strip "$kak_selection" '_') ;;
            *)  face=$kak_opt_render_markdown_italics; content=$(rm_strip "$kak_selection" '*') ;;
          esac
          rm_emit em "$face" "$content" ;;
      esac
    }
  }
  # end-sh-lib

  # shared per-selection pipeline: skip selections inside a language-tagged
  # code fence, then classify + emit. $1 = classification kind.
  define-command -hidden _render-markdown-handle -params 1 %{
    set-option global _render_markdown_kind %arg{1}
    evaluate-commands -itersel %{
      evaluate-commands %sh{
        # Ensure Kakoune passes all option vars used by the classifier.
        # kak_opt_render_markdown_heading_1 kak_opt_render_markdown_heading_2
        # kak_opt_render_markdown_heading_3 kak_opt_render_markdown_heading_4
        # kak_opt_render_markdown_heading_5 kak_opt_render_markdown_heading_6
        # kak_opt_render_markdown_checkbox_checked kak_opt_render_markdown_checkbox_unchecked
        # kak_opt_render_markdown_bullet kak_opt_render_markdown_horizontal_rule
        # kak_opt_render_markdown_blockquote kak_opt_render_markdown_link_image
        # kak_opt_render_markdown_link_web kak_opt_render_markdown_link_link
        # kak_opt_render_markdown_link_mail kak_opt_render_markdown_codeblock_start
        # kak_opt_render_markdown_codeblock_end kak_opt_render_markdown_strikethrough
        # kak_opt_render_markdown_italics kak_opt_render_markdown_bold
        # kak_opt_render_markdown_inline_code kak_opt__render_markdown_debug_file
        # kak_opt_render_markdown_table_separator kak_opt_render_markdown_table_pipe
        # kak_opt__render_markdown_consumed_lines kak_selection kak_selection_desc
        # kak_opt__render_markdown_fence_spans
        # Skip matches that start inside a non-markdown code fence (the codeblock
        # matcher ran first and recorded those spans).
        line=${kak_selection_desc%%.*}
        col=${kak_selection_desc#*.}
        col=${col%%,*}
        for span in $kak_opt__render_markdown_fence_spans; do
          start=${span%%,*}
          end=${span##*,}
          start_line=${start%%.*}
          start_col=${start#*.}
          end_line=${end%%.*}
          if [ "$line" -ge "$start_line" ] && [ "$line" -le "$end_line" ] &&
            [ "$col" -ge "$start_col" ]; then
            exit 0
          fi
        done
        eval "$kak_opt__render_markdown_sh_lib"
        render_markdown_classify "$kak_opt__render_markdown_kind"
      }
    }
  }


  define-command -hidden _render-markdown-match-headings %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^>?\h*#+\s<ret>s#+<ret>Gl"
        _render-markdown-handle heading
      }
    }
  }

  # Setext headings: a paragraph line followed by "===" (level 1) or "---"
  # (level 2).
  define-command -hidden _render-markdown-match-setext %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*[^\n]+\n\h*(=+|-+)\h*\n<ret>"
        _render-markdown-handle setext
      }
    }
  }

  # Whole-buffer fence scan: cheap, but a shell fork per fence glyph was not, so
  # the ranges are collected here and emitted in one shell call. Spans of
  # non-markdown fences are recorded for the guard (see _render-markdown-handle).
  define-command -hidden _render-markdown-match-codeblocks %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        # the info string excludes backticks, as CommonMark requires
        execute-keys "%%s```[^`\n]*\n((?:(?!```).)*)\n[^\n]*```<ret>"
        # Spans of non-markdown fences: inline kinds starting inside are skipped.
        # The opening line mentions markdown exactly when `smarkdown` matches in
        # it, so the try/catch below is the condition.
        evaluate-commands -itersel -draft %{
          set-register f "%val{selection_desc}"
          try %{
            execute-keys "<a-:><a-semicolon><semicolon>x"
            execute-keys "smarkdown<ret>"
          } catch %{
            evaluate-commands "set-option -add global _render_markdown_fence_spans '%reg{f}'"
          }
        }
        # opening and closing fence markers, emitted in one shell pass below
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><a-semicolon><semicolon>xs```<ret>"
          set-option -add global _render_markdown_fence_starts "%val{selection_desc}"
        }
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><semicolon>xs```<ret>"
          set-option -add global _render_markdown_fence_ends "%val{selection_desc}"
        }
        evaluate-commands %sh{
          # env vars must be referenced here (or in a comment) to be exported:
          # kak_opt__render_markdown_fence_starts kak_opt__render_markdown_fence_ends
          # kak_opt_render_markdown_codeblock_start
          # kak_opt_render_markdown_codeblock_end
          # kak_opt__render_markdown_debug_file
          eval "$kak_opt__render_markdown_sh_lib"
          emit_fence_ranges() { # $1 = marker ranges, $2 = escaped face
            quoted=$(rm_quote "$2")
            for d in $1; do
              printf "set-option -add window _render_markdown_bare_ranges '%s|%s'\n" "$d" "$quoted"
              if [ -n "$kak_opt__render_markdown_debug_file" ]; then
                printf '%s\n' "$d|$2" >>"$kak_opt__render_markdown_debug_file"
              fi
            done
          }
          # the face is the same for every fence, so escape it once
          start_face=$(rm_escape "$kak_opt_render_markdown_codeblock_start")
          end_face=$(rm_escape "$kak_opt_render_markdown_codeblock_end")
          emit_fence_ranges "$kak_opt__render_markdown_fence_starts" "$start_face"
          emit_fence_ranges "$kak_opt__render_markdown_fence_ends" "$end_face"
        }
      }
    }
  }

  define-command -hidden _render-markdown-match-lists %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*>?\h*>*(-\h\[[x<space>]\]|[-*+]\h|[0-9]{1,9}[.)]\h)<ret>s(-\h\[[x<space>]\]|[-*+]\h|[0-9]{1,9}[.)]\h)<ret>_L"
        _render-markdown-handle list
      }
    }
  }

  define-command -hidden _render-markdown-match-hrules %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*>?\h*>*(-(\h*-){2,}|_(\h*_){2,}|\*(\h*\*){2,})\h*\n<ret>s[-_*](\h*[-_*])*<ret>"
        _render-markdown-handle hrule
      }
    }
  }

  define-command -hidden _render-markdown-match-blockquotes %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*<gt>+\h*<ret>"
        _render-markdown-handle blockquote
      }
    }
  }

  define-command -hidden _render-markdown-match-tables %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*\|[^\n]*<ret>"
        _render-markdown-handle table
      }
    }
  }

  define-command -hidden _render-markdown-match-links %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s!?\[[^\[]+\]\([^\(]+\)<ret>"
        _render-markdown-handle link
      }
      try %{
        execute-keys "gtGbx"
        execute-keys "s!?\[[^\[]+\]\[[^\[]+\]<ret>"
        _render-markdown-handle link
      }
      try %{
        execute-keys "gtGbx"
        execute-keys "s<lt>\S+@\S+\.[^\n]+<gt><ret>"
        _render-markdown-handle link-mail
      }
    }
  }

  # emphasis family: combined regex from original, kept for reliable overlap
  # handling; per-match kind is decided by the library's emphasis dispatcher
  define-command -hidden _render-markdown-match-emphasis %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s(?<lt>!\w)(?<lt>!\\)(?:`[^`\n]+`|~~[^~\n]+~~|(?<lt>!\*)(?:\*\*\*[^*\n]+\*\*\*|\*\*[^*\n]+\*\*|\*[^*\n]+\*)(?!\*)|(?<lt>!_)(?:___[^_\n]+___|__[^_\n]+__|_[^_\n]+_)(?!_))(?!\w)<ret>"
        _render-markdown-handle emphasis
      }
    }
  }

  define-command render-markdown-enable %{
    hook -group render-markdown-update window NormalIdle .* _render-markdown-update
    add-highlighter window/_render_markdown_ranges replace-ranges _render_markdown_ranges
  }

  define-command render-markdown-disable %{
    remove-highlighter window/_render_markdown_ranges
    remove-hooks window render-markdown-update
  }

  define-command render-markdown-toggle %{
    try %{
      render-markdown-disable
    } catch %{
      render-markdown-enable
    }
  }

  # Select the table enclosing the cursor (a run of lines whose first
  # non-blank character is a |). Adapted from kakoune-table.
  define-command render-markdown-table-select %{
    try %{
      execute-keys "gi<a-k>\|<ret>"
    } catch %{
      fail 'not in a table'
    }
    evaluate-commands -save-regs '/' %{
      set-register / (?:\h*\|[^\n]*\n)+
      try %{
        execute-keys -draft "<a-C><a-space>"
        execute-keys -draft "kgi<a-k>\|<ret>"
        execute-keys "<a-n>"
      }
      execute-keys "<a-n>n"
    }
  }

  # Align the table enclosing the cursor: compute per-column widths and
  # rewrite every row with padded cells (separator rows get dash runs of
  # width+2, at least three dashes). Runs via the shell library, so it works
  # with uneven rows and keeps the first line's indentation.
  define-command render-markdown-table-format %{
    evaluate-commands -save-regs m %{
      render-markdown-table-select
      evaluate-commands %sh{
        eval "$kak_opt__render_markdown_sh_lib"
        aligned=$(printf '%s' "$kak_selection" | render_markdown_table_align)
        printf "set-register m '%s'\n" "$(rm_quote "$aligned")"
      }
      execute-keys 'd"mp'
    }
  }

  define-command -hidden _render-markdown-update %{
    set-option window _render_markdown_bare_ranges
    set-option global _render_markdown_consumed_lines
    # a bare set-option clears these str-list accumulators
    set-option global _render_markdown_fence_spans
    set-option global _render_markdown_fence_starts
    set-option global _render_markdown_fence_ends
    evaluate-commands -draft %{
      # matcher table: one command per feature, each re-selecting the viewable
      # buffer (gtGbx) before its search. Codeblocks come first because their
      # whole-buffer scan records the fence spans every other matcher consults.
      _render-markdown-match-codeblocks
      _render-markdown-match-headings
      # setext runs before hrules: its underline is consumed, so "Title" plus
      # "---" is a heading, while "# Title" plus "---" stays a break
      _render-markdown-match-setext
      # hrules before lists: a rule line ("- - -") is consumed by the rule
      # classifier, so the list matcher does not draw a bullet on it
      _render-markdown-match-hrules
      _render-markdown-match-lists
      _render-markdown-match-blockquotes
      _render-markdown-match-tables
      _render-markdown-match-links
      _render-markdown-match-emphasis
    }
    set-option window _render_markdown_ranges %val{timestamp} %opt{_render_markdown_bare_ranges}
  }
}

require-module render-markdown
