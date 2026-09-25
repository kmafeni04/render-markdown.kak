provide-module render-markdown %{

  declare-option -hidden str-list _render_markdown_bare_ranges
  declare-option -hidden range-specs _render_markdown_ranges
  declare-option -hidden str _render_markdown_kind ''
  declare-option -hidden str-list _render_markdown_consumed_lines ''
  declare-option -hidden str-list _render_markdown_fence_spans ''
  declare-option -hidden str-list _render_markdown_fence_starts ''
  declare-option -hidden str-list _render_markdown_fence_ends ''

  # render cache: the viewport probe, the last rendered line range (grown by
  # render_markdown_margin), and the buffer (name + timestamp) it belongs to
  declare-option -hidden str _render_markdown_view ''
  declare-option -hidden str _render_markdown_buf ''
  declare-option -hidden str _render_markdown_ts ''
  declare-option -hidden str _render_markdown_lines ''
  declare-option -hidden str _render_markdown_select_range ''
  declare-option -hidden str _render_markdown_cache ''
  declare-option -hidden str _render_markdown_cache_buf ''

  # how many lines beyond the viewport to render and cache, so scrolling
  # inside that margin does not re-run the matchers
  declare-option int render_markdown_margin 24

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

  # Embedded POSIX shell library (dash-verified), eval'd from the %sh blocks
  # below. Braces must stay balanced because Kakoune counts them even inside
  # quotes, so the library builds literal braces from octal where needed.
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
    # RM_NL is one newline, built without command substitution or a literal
    # brace so it is safe to embed in this option body.
    RM_NL=$(printf '\n_')
    RM_NL=${RM_NL%_}

    # literal brace characters, built from octal so no brace appears in this body
    OB=$(printf '\173')
    CB=$(printf '\175')

    # rm_chomp: drop one trailing newline from the current selection into $s
    rm_chomp() {
      s=${kak_selection%"$RM_NL"}
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
        printf '%s\n' "$range" >>"$kak_opt__render_markdown_debug_file"
      fi
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

    # face markup from a face option like {blue+f}󰲡 -> {blue+f}; the
    # close-brace char is built from octal (see the library header)
    rm_head() {
      cb=$CB
      case "$1" in
        *"$cb"*) printf '%s' "${1%%$cb*}$cb" ;;
        *) printf '' ;;
      esac
    }

    # merge two attributed face specs for nested emphasis, e.g.
    # {+b@Default} + {+i@Default} -> {+bi@Default}; otherwise keep the first
    rm_merge_face() { # $1, $2 = face specs
      ob=$OB
      cb=$CB
      a=${1#$ob}
      a=${a%$cb}
      b=${2#$ob}
      b=${b%$cb}
      case "$a/$b" in
        +*@*/+*@* | +*/+*)
          attrs=${a#+}
          rest=${attrs#*@}
          if [ "$rest" = "$attrs" ]; then rest=; else rest="@$rest"; fi
          attrs=${attrs%%@*}
          tail=${b#+}
          tail=${tail%%@*}
          while [ -n "$tail" ]; do
            c=${tail%"${tail#?}"}
            tail=${tail#?}
            case "$attrs" in
              *"$c"*) ;;
              *) attrs="$attrs$c" ;;
            esac
          done
          printf '%s' "$ob+$attrs$rest$cb"
          ;;
        *) printf '%s' "$1" ;;
      esac
    }

    # earliest span delimiter in $1, or empty
    rm_next_delim() {
      str=$1
      best=${#str} # no delimiter starts at or past the end of $str
      found=
      for tok in '`' '***' '**' '___' '__' '~~' '![' '[' '_' '*'; do
        case "$str" in
          *"$tok"*)
            front=${str%%"$tok"*}
            pos=${#front}
            if [ "$pos" -lt "$best" ]; then
              best=$pos
              found=$tok
            fi
            ;;
        esac
      done
      printf '%s' "$found"
    }

    # character helpers for the inline renderer.  "word" excludes underscore
    # (CommonMark counts it as punctuation), so it is the alnum class, not \w.
    rm_first_char() { printf '%s' "${1%"${1#?}"}"; }
    rm_last_char() { printf '%s' "${1#"${1%?}"}"; }
    rm_is_word() {
      case "$1" in
        [[:alnum:]]) return 0 ;;
        *) return 1 ;;
      esac
    }
    # empty (line edge) counts as whitespace, like CommonMark's flanking
    rm_is_space() {
      case "$1" in
        '' | [[:space:]]) return 0 ;;
        *) return 1 ;;
      esac
    }
    # can a delimiter run open?  $1 = delimiter, $2 = char before, $3 = char
    # after.  All runs need a non-space after; "*" additionally needs the
    # left-flanking rule (not punctuation after unless preceded by
    # space/punctuation) and "_" must not follow a word character.
    rm_can_open() {
      rm_is_space "$3" && return 1
      case "$1" in
        '_' | '__' | '___')
          rm_is_word "$2" && return 1
          ;;
        '~' | '~~') ;;
        *)
          if ! rm_is_word "$3"; then
            rm_is_word "$2" && return 1
          fi
          ;;
      esac
      return 0
    }
    # closing is the mirror of opening: swap the two sides
    rm_can_close() { rm_can_open "$1" "$3" "$2"; }

    # attribute string for an emphasis bitmask (b=2, i=1, s=4), e.g. 3 -> bi
    rm_attr_str() {
      a=$1
      str=
      [ $((a & 2)) -ne 0 ] && str="${str}b"
      [ $((a & 1)) -ne 0 ] && str="${str}i"
      [ $((a & 4)) -ne 0 ] && str="${str}s"
      printf '%s' "$str"
    }

    # face markup for an emphasis bitmask: reset ($3 = 0) or a span on $2
    rm_face_attr() { # $1 = base face, $2 = base inner, $3 = bitmask
      if [ "$3" -eq 0 ]; then
        printf '%s' "$1"
        return
      fi
      str=$(rm_attr_str "$3")
      case "$2" in
        *+*) printf '%s' "{${2%+*}+${2##*+}$str}" ;;
        *) printf '%s' "{${2}+$str}" ;;
      esac
    }

    # block-text face for an emphasis bitmask, built from the face options
    rm_face_mask() { # $1 = bitmask
      mask=$1
      face=
      if [ $((mask & 2)) -ne 0 ]; then face=$kak_opt_render_markdown_bold; fi
      if [ $((mask & 1)) -ne 0 ]; then
        if [ -n "$face" ]; then face=$(rm_merge_face "$face" "$kak_opt_render_markdown_italics")
        else face=$kak_opt_render_markdown_italics; fi
      fi
      if [ $((mask & 4)) -ne 0 ]; then
        if [ -n "$face" ]; then face=$(rm_merge_face "$face" "$kak_opt_render_markdown_strikethrough")
        else face=$kak_opt_render_markdown_strikethrough; fi
      fi
      printf '%s' "$face"
    }

    # CommonMark emphasis: scan $1 for "*"/"_" delimiter runs (and "~~"),
    # decide which can open and close from the flanking rules, then pair them.
    # A run that can both open and close cannot pair when the two run lengths
    # sum to a multiple of 3 unless both are (the "rule of 3").  Backslash
    # escapes are literal and inline code spans are skipped.  Positions are
    # 0-based byte offsets.
    #   RM_EMP_SPANS = "mstart,mend,cstart,cend,mask ..." (mask: i=1 b=2 s=4)
    #   RM_EMP_USED  = "p1,p2 ..." delimiter-marker ranges to drop
    #   rm_code_n, rm_cs/ce/ci* = inline code spans (full range and content)
    rm_emphasis_parse() {
      str=$1
      rm_e_n=0
      rm_code_n=0
      pos=0
      prev=
      while [ -n "$str" ]; do
        ch=${str%"${str#?}"}
        str=${str#?}
        case "$ch" in
          '\')
            next=${str%"${str#?}"}
            case "$next" in
              '*' | '_' | '~' | '`')
                str=${str#?}
                pos=$((pos + 2))
                prev=$next
                ;;
              *)
                pos=$((pos + 1))
                prev=$ch
                ;;
            esac
            ;;
          '`')
            if [ "$prev" != '`' ] && [ "${str%"${str#?}"}" != '`' ]; then
              case "$str" in
                *'`'*)
                  inner=${str%%'`'*}
                  rest=${str#"$inner"\`}
                  after=${rest%"${rest#?}"}
                  if [ -n "$inner" ] && [ "$after" != '`' ]; then
                    rm_code_n=$((rm_code_n + 1))
                    eval "rm_cs$rm_code_n=$pos"
                    eval "rm_ce$rm_code_n=$((pos + ${#inner} + 2))"
                    eval "rm_ci$rm_code_n=\$inner"
                    str=$rest
                    pos=$((pos + ${#inner} + 2))
                    prev='`'
                    continue
                  fi
                  ;;
              esac
            fi
            pos=$((pos + 1))
            prev=$ch
            ;;
          '*' | '_' | '~')
            len=1
            next=${str%"${str#?}"}
            while [ -n "$str" ] && [ "$next" = "$ch" ]; do
              str=${str#?}
              len=$((len + 1))
              next=${str%"${str#?}"}
            done
            if [ "$ch" = '~' ] && [ "$len" -ne 2 ]; then
              pos=$((pos + len))
              prev=$ch
              continue
            fi
            rm_e_n=$((rm_e_n + 1))
            eval "rm_ec$rm_e_n=\$ch"
            eval "rm_en$rm_e_n=\$len"
            eval "rm_ep$rm_e_n=\$pos"
            eval "rm_eb$rm_e_n=\$prev"
            eval "rm_ea$rm_e_n=\$next"
            eval "rm_erem$rm_e_n=0"
            pos=$((pos + len))
            prev=$ch
            ;;
          *)
            pos=$((pos + 1))
            prev=$ch
            ;;
        esac
      done
      i=1
      while [ "$i" -le "$rm_e_n" ]; do
        eval "c=\$rm_ec$i; b=\$rm_eb$i; a=\$rm_ea$i"
        eval "rm_eo$i=0; rm_el$i=0"
        if rm_can_open "$c" "$b" "$a"; then eval "rm_eo$i=1"; fi
        if rm_can_close "$c" "$b" "$a"; then eval "rm_el$i=1"; fi
        i=$((i + 1))
      done
      RM_EMP_SPANS=
      RM_EMP_USED=
      cur=1
      while [ "$cur" -le "$rm_e_n" ]; do
        eval "crem=\$rm_erem$cur; ccl=\$rm_el$cur; cch=\$rm_ec$cur"
        if [ "$crem" -eq 1 ] || [ "$ccl" -eq 0 ]; then
          cur=$((cur + 1))
          continue
        fi
        eval "cn=\$rm_en$cur; cpos=\$rm_ep$cur; cco=\$rm_eo$cur"
        op=$((cur - 1))
        found=0
        while [ "$op" -ge 1 ]; do
          eval "orem=\$rm_erem$op"
          if [ "$orem" -eq 0 ]; then
            eval "och=\$rm_ec$op; oco=\$rm_eo$op; ocl=\$rm_el$op; on=\$rm_en$op"
            if [ "$och" = "$cch" ] && [ "$oco" -eq 1 ]; then
              odd=0
              if { [ "$oco" -eq 1 ] && [ "$ocl" -eq 1 ]; } ||
                { [ "$cco" -eq 1 ] && [ "$ccl" -eq 1 ]; }; then
                if [ $(((on + cn) % 3)) -eq 0 ] &&
                  { [ $((on % 3)) -ne 0 ] || [ $((cn % 3)) -ne 0 ]; }; then
                  odd=1
                fi
              fi
              if [ "$odd" -eq 0 ]; then
                eval "opos=\$rm_ep$op"
                found=1
                break
              fi
            fi
          fi
          op=$((op - 1))
        done
        if [ "$found" -eq 0 ]; then
          if [ "$cco" -eq 0 ]; then eval "rm_erem$cur=1"; fi
          cur=$((cur + 1))
          continue
        fi
        if [ "$on" -ge 2 ] && [ "$cn" -ge 2 ]; then use=2; else use=1; fi
        case "$cch" in
          '~') mask=4 ;;
          *) if [ "$use" -eq 2 ]; then mask=2; else mask=1; fi ;;
        esac
        RM_EMP_SPANS="$RM_EMP_SPANS $((opos + on - use)),$((cpos + use)),$((opos + on)),$cpos,$mask"
        RM_EMP_USED="$RM_EMP_USED $((opos + on - use)),$((opos + on)) $cpos,$((cpos + use))"
        eval "rm_en$op=$((on - use))"
        eval "rm_ep$cur=$((cpos + use))"
        eval "rm_en$cur=$((cn - use))"
        k=$((op + 1))
        while [ "$k" -lt "$cur" ]; do
          eval "rm_erem$k=1"
          k=$((k + 1))
        done
        eval "on=\$rm_en$op; cn=\$rm_en$cur"
        if [ "$on" -eq 0 ]; then eval "rm_erem$op=1"; fi
        if [ "$cn" -eq 0 ]; then
          eval "rm_erem$cur=1"
          cur=$((cur + 1))
        fi
      done
    }

    # render plain heading/table text (no code, links or strikethrough) using
    # the spec emphasis spans; byte positions index $1
    rm_inline_spec() {
      txt=$1
      base=$2
      inside=${base#?}
      inside=${inside%?}
      rm_emphasis_parse "$txt"
      len=${#txt}
      i=0
      while [ "$i" -lt "$len" ]; do
        eval "rm_eattr$i=0; rm_eskip$i=0"
        i=$((i + 1))
      done
      for span in $RM_EMP_SPANS; do
        rest=${span#*,}
        rest=${rest#*,}
        cstart=${rest%%,*}
        rest=${rest#*,}
        cend=${rest%%,*}
        mask=${rest#*,}
        i=$cstart
        while [ "$i" -lt "$cend" ]; do
          eval "rm_eattr$i=$((rm_eattr$i | mask))"
          i=$((i + 1))
        done
      done
      for mark in $RM_EMP_USED; do
        i=${mark%%,*}
        end=${mark#*,}
        while [ "$i" -lt "$end" ]; do
          eval "rm_eskip$i=1"
          i=$((i + 1))
        done
      done
      out=
      attr=0
      i=0
      rest=$txt
      while [ -n "$rest" ]; do
        ch=${rest%"${rest#?}"}
        rest=${rest#?}
        eval "a=\$rm_eattr$i; sk=\$rm_eskip$i"
        if [ "$sk" -eq 0 ]; then
          if [ "$a" -ne "$attr" ]; then
            attr=$a
            out="$out$(rm_face_attr "$base" "$inside" "$attr")"
          fi
          out="$out$ch"
        fi
        i=$((i + 1))
      done
      if [ "$attr" -ne 0 ]; then out="$out$base"; fi
      printf '%s' "$out"
    }

    # render line bytes [start,end) as block markup: drop used markers and
    # backticks, emit the union emphasis faces, and render code spans
    rm_render_block_region() { # $1 = start, $2 = end
      from=$1
      to=$2
      out=
      attr=0
      i=$from
      while [ "$i" -lt "$to" ]; do
        eval "ce=\$rm_ecode$i"
        if [ -n "$ce" ]; then
          eval "inner=\$rm_ecodeinner$i"
          out="$out$kak_opt_render_markdown_inline_code$inner"
          if [ "$attr" -ne 0 ]; then out="$out$(rm_face_mask "$attr")"; fi
          i=$ce
          continue
        fi
        eval "sk=\$rm_eskip$i"
        if [ "$sk" -eq 0 ]; then
          eval "a=\$rm_eattr$i"
          if [ "$a" -ne "$attr" ]; then
            attr=$a
            if [ "$attr" -ne 0 ]; then out="$out$(rm_face_mask "$attr")"; fi
          fi
          eval "out=\"\$out\$rm_echar$i\""
        fi
        i=$((i + 1))
      done
      printf '%s' "$out"
    }

    # render inline markdown spans in heading content as face markup: a span
    # adds its attribute to the inherited base face and resets to it, so the
    # whole heading keeps one color (links/code keep their faces).  Spans are
    # rendered recursively, so nested emphasis and triple markers work; code
    # and link labels stay literal.  Emphasis runs follow CommonMark's
    # left/right-flanking rules ("_" never emphasizes inside a word).
    rm_inline() {
      s=$1
      base=$2
      # plain emphasis (no code, links or strikethrough) uses the spec parser
      case "$s" in
        *'`'* | *'['* | *'~'*) ;;
        *)
          rm_inline_spec "$s" "$base"
          return
          ;;
      esac
      inside=${base#?}
      inside=${inside%?}
      out=
      # source character immediately before the current position (line start
      # is empty), needed for the flanking checks
      prev=
      while [ -n "$s" ]; do
        d=$(rm_next_delim "$s")
        if [ -z "$d" ]; then
          out="$out$s"
          break
        fi
        front=${s%%"$d"*}
        out="$out$front"
        s=${s#"$front"}
        s=${s#"$d"}
        if [ -n "$front" ]; then
          prev=$(rm_last_char "$front")
        fi
        case "$d" in
          '`')
            case "$s" in
              *\`*)
                inner=${s%%\`*}
                out="$out$kak_opt_render_markdown_inline_code$inner$base"
                s=${s#*"$inner"\`}
                prev='`'
                ;;
              *)
                out="$out\`$s"
                s=
                ;;
            esac
            ;;
          '***' | '___' | '**' | '__' | '~~' | '*' | '_')
            case "$d" in
              '***' | '___') attr=bi ;;
              '**' | '__') attr=b ;;
              '~~') attr=s ;;
              '*' | '_') attr=i ;;
            esac
            # a run that cannot open is literal, so a later run can open
            q=$(rm_first_char "$s")
            if ! rm_can_open "$d" "$prev" "$q"; then
              out="$out$d"
              prev=$(rm_last_char "$d")
              continue
            fi
            # find the closer, re-tokenizing so runs match the opener ("**"
            # is one token).  A run that can neither close nor open (an
            # intraword "_") is content; one that could open pairs with an
            # inner span, leaving this run literal.
            inner=
            found=0
            scan=$s
            while [ -n "$scan" ]; do
              tok=$(rm_next_delim "$scan")
              if [ -z "$tok" ]; then
                break
              fi
              head=${scan%%"$tok"*}
              tail=${scan#*"$head""$tok"}
              if [ "$tok" = "$d" ] && [ -n "$head" ]; then
                cp=$(rm_last_char "$head")
                cq=$(rm_first_char "$tail")
                if rm_can_close "$d" "$cp" "$cq"; then
                  inner="$inner$head"
                  rest=$tail
                  found=1
                  break
                fi
                if rm_can_open "$d" "$cp" "$cq"; then
                  break
                fi
              fi
              inner="$inner$head$tok"
              scan=$tail
            done
            if [ "$found" -eq 0 ]; then
              out="$out$d"
              prev=$(rm_last_char "$d")
              continue
            fi
            # merge the attribute into the base's attribute token:
            # {blue+f} + b -> {blue+fb}, {blue} + b -> {blue+b}
            case "$inside" in
              *+*) span="{${inside%+*}+${inside##*+}$attr}" ;;
              *) span="{${inside}+$attr}" ;;
            esac
            out="$out$span$(rm_inline "$inner" "$span")$base"
            s=$rest
            prev=$(rm_last_char "$d")
            ;;
          '![')
            case "$s" in
              *\]*)
                label=${s%%\]*}
                out="$out$kak_opt_render_markdown_link_image$label$base"
                s=${s#*"$label"]}
                # drop the (url) part; trailing text after it is kept
                case "$s" in
                  \(*\)*)
                    s=${s#\(}
                    s=${s#*\)}
                    prev=')'
                    ;;
                  *)
                    prev=']'
                    ;;
                esac
                ;;
            esac
            ;;
          '[')
            case "$s" in
              *\]\(*)
                label=${s%%\]*}
                rest=${s#*"$label"]}
                case "$rest" in
                  \(*\)*)
                    url=${rest#\(}
                    url=${url%%\)*}
                    case "$url" in
                      *http*) out="$out$kak_opt_render_markdown_link_web$label$base" ;;
                      *) out="$out$kak_opt_render_markdown_link_link$label$base" ;;
                    esac
                    s=${rest#\("$url"\)}
                    prev=')'
                    ;;
                  *)
                    out="$out[$label$rest"
                    s=
                    ;;
                esac
                ;;
              *)
                out="$out[$s"
                s=
                ;;
            esac
            ;;
        esac
      done
      printf '%s' "$out"
    }

    # Display width of a string: East Asian wide characters and emoji count
    # two columns, zero-width marks count none, everything else one.  od gives
    # raw bytes, so the UTF-8 decoding does not depend on the shell locale.
    rm_width() {
      case "$1" in
        *[!\ -~]*) ;; # non-printable-ASCII byte: decode below
        *) printf '%s' "${#1}"; return ;;
      esac
      printf '%s' "$1" | od -An -tu1 | awk '
        function wide(c) {
          if (c >= 4352 && c <= 4447) return 1
          if (c >= 11904 && c <= 12350) return 1
          if (c >= 12353 && c <= 13311) return 1
          if (c >= 13312 && c <= 19903) return 1
          if (c >= 19968 && c <= 40959) return 1
          if (c >= 40960 && c <= 42191) return 1
          if (c >= 44032 && c <= 55203) return 1
          if (c >= 63744 && c <= 64255) return 1
          if (c >= 65040 && c <= 65049) return 1
          if (c >= 65072 && c <= 65135) return 1
          if (c >= 65280 && c <= 65376) return 1
          if (c >= 65504 && c <= 65510) return 1
          if (c >= 127744 && c <= 128591) return 1
          if (c >= 129280 && c <= 129535) return 1
          if (c >= 131072 && c <= 196605) return 1
          if (c >= 196608 && c <= 262141) return 1
          return 0
        }
        function zero(c) {
          if (c >= 768 && c <= 879) return 1
          if (c >= 8203 && c <= 8207) return 1
          if (c == 8205) return 1
          if (c >= 65024 && c <= 65039) return 1
          if (c >= 127995 && c <= 127999) return 1
          return 0
        }
        { for (i = 1; i <= NF; i++) b[++n] = $i }
        END {
          w = 0
          i = 1
          while (i <= n) {
            b1 = b[i]
            if (b1 < 128) { c = b1; i += 1 }
            else if (b1 < 224) { c = (b1 - 192) * 64 + (b[i + 1] - 128); i += 2 }
            else if (b1 < 240) {
              c = (b1 - 224) * 4096 + (b[i + 1] - 128) * 64 + (b[i + 2] - 128)
              i += 3
            } else {
              c = (b1 - 240) * 262144 + (b[i + 1] - 128) * 4096 + (b[i + 2] - 128) * 64 + (b[i + 3] - 128)
              i += 4
            }
            if (zero(c)) continue
            w += wide(c) ? 2 : 1
          }
          print w
        }
      '
    }

    # Visible display width of face-marked text: drop the {...} face specs
    # (they are not drawn) before measuring.
    rm_visible_width() {
      rm_width "$(printf '%s' "$1" | sed "s/$OB[^$CB]*$CB//g")"
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
            *\|*)
              seg=${rest%%\|*}
              rest=${rest#*\|}
              ;;
            *)
              seg=$rest
              rest=
              ;;
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
        hasdash=0
        sep=1
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
            len=$(rm_width "$seg")
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
            d=$((w + 2))
            [ "$d" -lt 3 ] && d=3
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
            cw=$(rm_width "$cell")
            nsp=$((w - cw))
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
        front-matter)
          # A leading YAML front matter block is hidden and consumed, so its
          # opening/closing "---" never renders as a rule or setext underline.
          # The matcher only produces line-1 matches; guard anyway.
          [ "$(rm_line)" -eq 1 ] || exit 0
          rm_chomp
          nl=$RM_NL
          line=1
          consumed=
          rest=$s
          while :; do
            case "$rest" in
              *"$nl"*)
                cur=${rest%%$nl*}
                rest=${rest#*$nl}
                ;;
              *)
                cur=$rest
                rest=
                ;;
            esac
            bytes=$(($(printf '%s' "$cur" | wc -c)))
            rm_emit_desc "$line.1,$line.$bytes" ''
            consumed="$consumed $line"
            line=$((line + 1))
            [ -n "$rest" ] || break
          done
          printf "set-option -add global _render_markdown_consumed_lines%s\n" "$consumed"
          ;;
        heading)
          level=$(printf '%s' "$kak_selection" | grep -o '^#*' | wc -c)
          level=$((level - 1))
          if [ "$level" -gt 6 ]; then exit 0; fi
          eval "face=\$kak_opt_render_markdown_heading_$level"
          content=$(printf '%s' "$kak_selection" | sed -e 's/^#*//' -e "s/'/''/g")
          rm_emit heading "$face" "$(rm_inline "$content" "$(rm_head "$face")")"
          # the whole heading line is consumed; inline kinds must not match inside it
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$(rm_line)"
          ;;
        setext)
          # A setext underline turns the whole preceding paragraph into a
          # heading.  The matcher finds the underline and expands the
          # selection with the paragraph text object (<a-i>p), so the
          # selection is every text line followed by the underline.  Face
          # each text line, hide the underline, consume all of them.
          if rm_consumed; then exit 0; fi
          rm_chomp
          nl=$RM_NL
          case "$s" in
            *"$nl"*) ;; # need at least one text line plus the underline
            *) exit 0 ;;
          esac
          underline=${s##*$nl}
          text=${s%$nl*}
          # Split the text into lines, then take the longest suffix of plain
          # paragraph lines immediately before the underline.  A block
          # construct (heading, quote, list marker, fence, thematic break)
          # interrupts a paragraph, so it ends the heading there; leading
          # indentation on a plain line is allowed.
          bt=$(printf '\140') # backtick char, so no command substitution
          rest=$text
          rows=0
          while :; do
            case "$rest" in
              *"$nl"*)
                line=${rest%%$nl*}
                rest=${rest#*$nl}
                ;;
              *)
                line=$rest
                rest=
                ;;
            esac
            rows=$((rows + 1))
            eval "row$rows=\$line"
            [ -n "$rest" ] || break
          done
          first_row=$((rows + 1))
          i=$rows
          while [ "$i" -ge 1 ]; do
            eval "line=\$row$i"
            stripped=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
            first=$(printf '%.1s' "$stripped")
            ok=1
            case "$stripped" in
              '') ok=0 ;;         # blank line ends the paragraph
              *[!_[:space:]]*) ;; # has real content
              *) ok=0 ;;          # only underscores/spaces: a thematic break
            esac
            case "$first" in
              '#' | '>' | '-' | '*' | '+' | '=' | '~' | '_' | "$bt" | [0-9]) ok=0 ;;
            esac
            [ "$ok" -eq 1 ] || break
            first_row=$i
            i=$((i - 1))
          done
          # no plain paragraph line directly above the underline: not a setext
          [ "$first_row" -le "$rows" ] || exit 0
          case "$underline" in
            =*) face=$kak_opt_render_markdown_heading_1 ;;
            *) face=$kak_opt_render_markdown_heading_2 ;;
          esac
          face=$(rm_head "$face") # no marker to replace, so no glyph either
          # range columns count bytes, not characters: wc -c, whose padding
          # $(( )) normalises.  The first text row is first_row, which sits at
          # selection line + first_row - 1.
          line=$(($(rm_line) + first_row - 1))
          consumed=
          i=$first_row
          while [ "$i" -le "$rows" ]; do
            eval "text=\$row$i"
            text_bytes=$(($(printf '%s' "$text" | wc -c)))
            rm_emit_desc "$line.1,$line.$text_bytes" "$face" "$(rm_inline "$text" "$face")"
            consumed="$consumed $line"
            line=$((line + 1))
            i=$((i + 1))
          done
          underline_bytes=$(($(printf '%s' "$underline" | wc -c)))
          rm_emit_desc "$line.1,$line.$underline_bytes" ''
          consumed="$consumed $line"
          printf "set-option -add global _render_markdown_consumed_lines%s\n" "$consumed"
          ;;
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
          rm_emit list "$face" "$content"
          ;;
        hrule)
          if rm_consumed; then exit 0; fi
          rm_emit hrule "$kak_opt_render_markdown_horizontal_rule" ''
          # the rule line is consumed: emphasis markers inside it must not match
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$(rm_line)"
          ;;
        blockquote)
          # replace the leading '>' run with one glyph per '>' (whitespace is
          # kept): '> ' -> '▋ ', '>text' -> '▋text', '>> t' -> '▋▋ t'
          cb=$CB # close-brace char (see the library header)
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
          rm_emit blockquote "$head" "$drawn"
          ;;
        table)
          # rows are consumed so inline kinds never render inside cells.
          # Separator rows (only dashes/colons between pipes) are redrawn as a
          # connecting grid line, e.g. |---|----| -> ├────┼──┤; other rows get
          # each pipe replaced by a box-drawing bar (│). All replacement
          # glyphs are single-width, so column alignment is never disturbed.
          pos=${kak_selection_desc%%,*}
          line=${pos%%.*}
          col=${pos#*.}
          sep=0
          case "$kak_selection" in
            *[!\|:[:space:]-]*) ;; # cell text: not a separator row
            *[-:]*) sep=1 ;;
          esac
          if [ "$sep" -eq 1 ]; then
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
                  if [ "$n" -eq 1 ]; then
                    c='├'
                  elif [ "$n" -eq "$pipes" ]; then
                    c='┤'
                  else c='┼'; fi
                  ;;
                '-' | ':') c='─' ;;
              esac
              drawn="$drawn$c"
            done
            rm_emit table "$kak_opt_render_markdown_table_separator" "$drawn"
          else
            # byte offsets, not characters: grep -ob, since a cell may hold
            # multi-byte characters and Kakoune range columns count bytes
            offs=$(printf '%s' "$kak_selection" | grep -ob '|' | cut -d: -f1)
            for off in $offs; do
              rm_emit_desc "$line.$((col + off))+1" "$kak_opt_render_markdown_table_pipe" '│'
            done
            # Inline markdown inside cells: each cell is replaced by the same
            # text rendered as face markup and padded with spaces so the cell
            # keeps its display width and the pipes never move.  A cell whose
            # rendering would grow (rare) is left raw.  Cells are bounded by
            # consecutive pipe byte offsets.
            prev=
            for off in $offs; do
              if [ -n "$prev" ] && [ "$off" -gt "$((prev + 1))" ]; then
                cell=$(printf '%s' "$kak_selection" | cut -b "$((prev + 2))-$off")
                rendered=$(rm_inline "$cell" '{}')
                if [ "$rendered" != "$cell" ]; then
                  ow=$(rm_width "$cell")
                  rw=$(rm_visible_width "$rendered")
                  pad=$((ow - rw))
                  if [ "$pad" -ge 0 ]; then
                    [ "$pad" -gt 0 ] && rendered="$rendered$(printf '%*s' "$pad" '')"
                    rm_emit_desc "$line.$((col + prev + 1)),$line.$((col + off - 1))" '' "$rendered"
                  fi
                fi
              fi
              prev=$off
            done
          fi
          printf "set-option -add global _render_markdown_consumed_lines %s\n" "$line"
          ;;
        link)
          if rm_consumed; then exit 0; fi
          content=$(printf '%s' "$kak_selection" | sed -e 's/^!//' -e 's/^\[//' -e 's/\]\(.*\)$//' -e 's/\]\[.*$//' -e "s/'/''/g")
          case "$kak_selection" in
            !*) face=$kak_opt_render_markdown_link_image ;;
            *http*) face=$kak_opt_render_markdown_link_web ;;
            *) face=$kak_opt_render_markdown_link_link ;;
          esac
          rm_emit link "$face" "$content"
          ;;
        link-mail)
          if rm_consumed; then exit 0; fi
          content=$(printf '%s' "$kak_selection" | sed -e 's/^<//' -e 's/>$//' -e "s/'/''/g")
          rm_emit link "$kak_opt_render_markdown_link_mail" "$content"
          ;;
        emphasis)
          if rm_consumed; then exit 0; fi
          line=$(rm_line)
          txt=$kak_selection
          rm_emphasis_parse "$txt"
          i=0
          rest=$txt
          while [ -n "$rest" ]; do
            ch=${rest%"${rest#?}"}
            rest=${rest#?}
            eval "rm_echar$i=\$ch"
            eval "rm_eattr$i=0; rm_eskip$i=0; rm_ecode$i=; rm_etop$i=; rm_esolo$i="
            i=$((i + 1))
          done
          for span in $RM_EMP_SPANS; do
            rest=${span#*,}
            rest=${rest#*,}
            cstart=${rest%%,*}
            rest=${rest#*,}
            cend=${rest%%,*}
            mask=${rest#*,}
            i=$cstart
            while [ "$i" -lt "$cend" ]; do
              eval "rm_eattr$i=$((rm_eattr$i | mask))"
              i=$((i + 1))
            done
          done
          for mark in $RM_EMP_USED; do
            i=${mark%%,*}
            end=${mark#*,}
            while [ "$i" -lt "$end" ]; do
              eval "rm_eskip$i=1"
              i=$((i + 1))
            done
          done
          ci=1
          while [ "$ci" -le "$rm_code_n" ]; do
            eval "cs=\$rm_cs$ci; ce=\$rm_ce$ci; ctext=\$rm_ci$ci"
            eval "rm_ecode$cs=\$ce; rm_ecodeinner$cs=\$ctext"
            eval "rm_eskip$cs=1; rm_eskip$((ce - 1))=1"
            ci=$((ci + 1))
          done
          for span in $RM_EMP_SPANS; do
            mstart=${span%%,*}
            r=${span#*,}
            mend=${r%%,*}
            top=1
            for other in $RM_EMP_SPANS; do
              [ "$other" = "$span" ] && continue
              omstart=${other%%,*}
              or=${other#*,}
              omend=${or%%,*}
              if [ "$omstart" -le "$mstart" ] && [ "$omend" -ge "$mend" ] &&
                { [ "$omstart" -lt "$mstart" ] || [ "$omend" -gt "$mend" ]; }; then
                top=0
                break
              fi
            done
            if [ "$top" -eq 1 ]; then eval "rm_etop$mstart=$mend"; fi
          done
          ci=1
          while [ "$ci" -le "$rm_code_n" ]; do
            eval "cs=\$rm_cs$ci; ce=\$rm_ce$ci"
            inside=0
            for span in $RM_EMP_SPANS; do
              mstart=${span%%,*}
              r=${span#*,}
              mend=${r%%,*}
              if [ "$cs" -ge "$mstart" ] && [ "$ce" -le "$mend" ]; then
                inside=1
                break
              fi
            done
            if [ "$inside" -eq 0 ]; then eval "rm_esolo$cs=$ce"; fi
            ci=$((ci + 1))
          done
          i=0
          while [ "$i" -lt "${#txt}" ]; do
            eval "te=\$rm_etop$i"
            if [ -n "$te" ]; then
              rm_emit_desc "$line.$((i + 1)),$line.$te" '' "$(rm_render_block_region "$i" "$te")"
            fi
            eval "se=\$rm_esolo$i"
            if [ -n "$se" ]; then
              eval "ctext=\$rm_ecodeinner$i"
              rm_emit_desc "$line.$((i + 1)),$line.$se" '' "$kak_opt_render_markdown_inline_code$ctext"
            fi
            i=$((i + 1))
          done
          ;;
      esac
    }
  }

  # shared per-selection pipeline: skip selections inside a language-tagged
  # code fence, then classify + emit. $1 = classification kind.
  define-command -hidden _render-markdown-handle -params 1 %{
    set-option global _render_markdown_kind %arg{1}
    evaluate-commands -itersel %{
      evaluate-commands %sh{
        # Load-bearing: Kakoune only exports an option to %sh if its name is
        # referenced here (the classifier reads them from the environment), so
        # deleting a name silently disables that feature.
        # kak_opt_render_markdown_heading_1 kak_opt_render_markdown_heading_2
        # kak_opt_render_markdown_heading_3 kak_opt_render_markdown_heading_4
        # kak_opt_render_markdown_heading_5 kak_opt_render_markdown_heading_6
        # kak_opt_render_markdown_checkbox_checked kak_opt_render_markdown_checkbox_unchecked
        # kak_opt_render_markdown_bullet kak_opt_render_markdown_horizontal_rule
        # kak_opt_render_markdown_blockquote kak_opt_render_markdown_link_image
        # kak_opt_render_markdown_link_web kak_opt_render_markdown_link_link
        # kak_opt_render_markdown_link_mail kak_opt_render_markdown_strikethrough
        # kak_opt_render_markdown_italics kak_opt_render_markdown_bold
        # kak_opt_render_markdown_inline_code kak_opt__render_markdown_debug_file
        # kak_opt_render_markdown_table_separator kak_opt_render_markdown_table_pipe
        # kak_opt__render_markdown_consumed_lines kak_selection
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


  # Select the range the matchers scan (viewport plus render_markdown_margin).
  # `select` leaves the cursor in place, so it never scrolls the window.
  define-command -hidden _render-markdown-select %{
    select "%opt{_render_markdown_select_range}"
  }

  define-command -hidden _render-markdown-match-headings %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^>?\h*#+\s<ret>s#+<ret>Gl"
        _render-markdown-handle heading
      }
    }
  }

  # YAML front matter: a leading "---" line, the YAML lines, and a closing
  # "---" line before the first blank line.  Non-CommonMark heuristic (see
  # README), so it is matched and consumed before anything else can render its
  # delimiters.  The tempered lookahead keeps the group from swallowing the
  # closing delimiter (or running past a blank line into the document body).
  define-command -hidden _render-markdown-match-frontmatter %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^---\h*\n(?:(?!---\n)(?!\n)[^\n]*\n)*---\h*\n<ret>"
        _render-markdown-handle front-matter
      }
    }
  }

  # Setext headings: a paragraph followed by "===" (level 1) or "---"
  # (level 2). The underline is found first, then the paragraph text object
  # (<a-i>p) expands the selection to the whole preceding paragraph, so a
  # multi-line paragraph is covered as well.
  define-command -hidden _render-markdown-match-setext %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^\h*(=+|-+)\h*$<ret>"
        execute-keys "<a-i>p"
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
        # One alternative per fence length, longest first: the engine has no
        # backreferences, so "closing fence at least as long as the opening
        # one" is expressed by pairing equal-length runs.  The content guard
        # excludes only the current length, so a longer fence may contain
        # shorter fences (e.g. a four-backtick block documenting a three).
        # The info string excludes backticks, as CommonMark requires.
        execute-keys "%%s``````[^`\n]*\n((?:(?!``````).)*)\n[^\n]*``````(?![`])|`````[^`\n]*\n((?:(?!`````).)*)\n[^\n]*`````(?![`])|````[^`\n]*\n((?:(?!````).)*)\n[^\n]*````(?![`])|```[^`\n]*\n((?:(?!```).)*)\n[^\n]*```(?![`])<ret>"
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
        # opening and closing fence markers, emitted in one shell pass below.
        # The marker run is matched with `+ so four-plus-backtick fences are
        # covered by the same range as three-backtick ones.
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><a-semicolon><semicolon>xs`+<ret>"
          set-option -add global _render_markdown_fence_starts "%val{selection_desc}"
        }
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><semicolon>xs`+<ret>"
          set-option -add global _render_markdown_fence_ends "%val{selection_desc}"
        }
        evaluate-commands %sh{
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
      _render-markdown-select
      try %{
        execute-keys "s^\h*>?\h*>*(-\h\[[x<space>]\]|[-*+]\h|[0-9]{1,9}[.)]\h)<ret>s(-\h\[[x<space>]\]|[-*+]\h|[0-9]{1,9}[.)]\h)<ret>_L"
        _render-markdown-handle list
      }
    }
  }

  define-command -hidden _render-markdown-match-hrules %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^\h*>?\h*>*(-(\h*-){2,}|_(\h*_){2,}|\*(\h*\*){2,})\h*\n<ret>s[-_*](\h*[-_*])*<ret>"
        _render-markdown-handle hrule
      }
    }
  }

  define-command -hidden _render-markdown-match-blockquotes %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^\h*<gt>+\h*<ret>"
        _render-markdown-handle blockquote
      }
    }
  }

  define-command -hidden _render-markdown-match-tables %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^\h*\|[^\n]*<ret>"
        _render-markdown-handle table
      }
    }
  }

  define-command -hidden _render-markdown-match-links %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s!?\[[^\[]+\]\([^()]+\)<ret>"
        _render-markdown-handle link
      }
      try %{
        _render-markdown-select
        execute-keys "s!?\[[^\[]+\]\[[^\[]+\]<ret>"
        _render-markdown-handle link
      }
      try %{
        _render-markdown-select
        execute-keys "s<lt>\S+@\S+\.[^\n]+<gt><ret>"
        _render-markdown-handle link-mail
      }
    }
  }

  # inline spans: each line is parsed by the shell library, which pairs "*",
  # "_" and "~~" runs with CommonMark's flanking rules and rule of 3 and
  # renders inline code.  Links are handled by their own matcher.
  define-command -hidden _render-markdown-match-emphasis %{
    evaluate-commands -draft %{
      _render-markdown-select
      try %{
        execute-keys "s^[^\n]+$<ret>"
        _render-markdown-handle emphasis
      }
    }
  }

  define-command render-markdown-enable %{
    set-option window _render_markdown_cache ''
    set-option window _render_markdown_cache_buf ''
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
        # The selection ends with a newline; keep the register linewise so the
        # line after the table is not joined onto its last row.
        printf "set-register m '%s\n'\n" "$(rm_quote "$aligned")"
      }
      execute-keys 'd"mP'
    }
  }

  define-command -hidden _render-markdown-render %{
    set-option window _render_markdown_bare_ranges
    set-option global _render_markdown_consumed_lines
    # a bare set-option clears these str-list accumulators
    set-option global _render_markdown_fence_spans
    set-option global _render_markdown_fence_starts
    set-option global _render_markdown_fence_ends
    evaluate-commands -draft %{
      # matcher table: one command per feature, each re-selecting the render
      # range (_render-markdown-select) before its search.  Front matter runs
      # first so its delimiters never render as rules or headings; codeblocks
      # run next because their whole-buffer scan records the fence spans every
      # other matcher consults.
      _render-markdown-match-frontmatter
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

  # Re-render only when the buffer changed or the viewport left the cached
  # band; a scroll inside the band is a no-op.
  define-command -hidden _render-markdown-update %{
    set-option global _render_markdown_buf %val{bufname}
    set-option global _render_markdown_ts %val{timestamp}
    set-option global _render_markdown_lines %val{buf_line_count}
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      set-option global _render_markdown_view %val{selection_desc}
    }
    evaluate-commands %sh{
      view=$kak_opt__render_markdown_view
      vtop=${view%%.*}
      vbot=${view#*,}
      vbot=${vbot%%.*}
      buf=$kak_opt__render_markdown_buf
      ts=$kak_opt__render_markdown_ts
      lines=$kak_opt__render_markdown_lines
      margin=$kak_opt_render_markdown_margin
      mtop=$((vtop - margin))
      [ "$mtop" -lt 1 ] && mtop=1
      mbot=$((vbot + margin))
      [ "$mbot" -gt "$lines" ] && mbot=$lines
      # the cache is window-scoped, so it also has to match the buffer
      set -- $kak_opt__render_markdown_cache
      if [ "$kak_opt__render_markdown_cache_buf" = "$buf" ] &&
        [ "$1" = "$ts" ] && [ "$vtop" -ge "$2" ] && [ "$vbot" -le "$3" ]; then
        exit 0
      fi
      # select clamps the column but not the line; mtop/mbot are clamped above
      printf "set-option global _render_markdown_select_range '%s.1,%s.999999'\n" "$mtop" "$mbot"
      printf "set-option window _render_markdown_cache '%s %s %s'\n" "$ts" "$mtop" "$mbot"
      # %val{bufname} is expanded by Kakoune, so quoting is handled for us
      printf '%s\n' 'set-option window _render_markdown_cache_buf %val{bufname}'
      printf '_render-markdown-render\n'
    }
  }
}

require-module render-markdown
