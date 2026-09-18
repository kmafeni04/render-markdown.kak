provide-module render-markdown %{

  declare-option -hidden str-list _render_markdown_bare_ranges
  declare-option -hidden range-specs _render_markdown_ranges
  declare-option -hidden str _render_markdown_kind ''
  declare-option -hidden str-list _render_markdown_consumed_lines ''

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
    rm_quote() {
      printf '%s' "$1" | sed "s/'/''/g"
    }

    # emit one bare range: <desc>|<face><text>, + debug-file mirror
    rm_emit() {
      range="$kak_selection_desc|$(rm_escape "$2$3")"
      printf "set-option -add window _render_markdown_bare_ranges '%s'\n" "$(rm_quote "$range")"
      if [ -n "$kak_opt__render_markdown_debug_file" ]; then
        printf '%s\n' "$range" >> "$kak_opt__render_markdown_debug_file"
      fi
    }

    rm_strip() {
      printf '%s' "$1" | tr -d "$2"
    }

    # escape | and \ per the range-specs syntax
    rm_escape() {
      printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/|/\\|/g'
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
      printf '%s' "${1%%$cb*}$cb"
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
        list)
          case "$kak_selection" in
            -*\[x\]*)   face=$kak_opt_render_markdown_checkbox_checked ;;
            -*\[*\]*)   face=$kak_opt_render_markdown_checkbox_unchecked ;;
            *)          face=$kak_opt_render_markdown_bullet ;;
          esac
          rm_emit list "$face" '' ;;
        hrule)
          rm_emit hrule "$kak_opt_render_markdown_horizontal_rule" '' ;;
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
        codeblock-start)
          rm_emit codeblock "$kak_opt_render_markdown_codeblock_start" '' ;;
        codeblock-end)
          rm_emit codeblock "$kak_opt_render_markdown_codeblock_end" '' ;;
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
                __*|\*\**) render_markdown_classify em-double ;;
                *) render_markdown_classify em-single ;;
              esac
              ;;
          esac
          ;;
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
    evaluate-commands -save-regs 'i' -itersel %{
      set-register i ''
      evaluate-commands -draft %{
        try %{
          execute-keys "<a-a>c```\w*,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w*<ret>"
          evaluate-commands %sh{
            if ! printf '%s' "$kak_selection" | grep 'markdown'; then
              printf "set-register i 'inside'\n"
            fi
          }
        }
      }
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
        # kak_opt__render_markdown_consumed_lines kak_selection kak_selection_desc kak_main_reg_i
        if [ -n "$kak_main_reg_i" ]; then
          exit 0
        fi
        eval "$kak_opt__render_markdown_sh_lib"
        render_markdown_classify "$kak_opt__render_markdown_kind"
      }
    }
  }

  # static-face emit for codeblock markers (no fence guard)
  define-command -hidden _render-markdown-emit-static -params 1 %{
    set-option global _render_markdown_kind %arg{1}
    evaluate-commands %sh{
      # Only codeblock faces are used here; env-var refs must be declared in
      # each block that uses them (see _render-markdown-handle for the full set).
      # kak_opt_render_markdown_codeblock_start kak_opt_render_markdown_codeblock_end
      # kak_opt__render_markdown_debug_file kak_selection kak_selection_desc
      eval "$kak_opt__render_markdown_sh_lib"
      render_markdown_classify "$kak_opt__render_markdown_kind"
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

  define-command -hidden _render-markdown-match-codeblocks %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "%%s```[\w+-]*\n((?:(?!```).)*)\n[^\n]*```<ret>"
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><a-semicolon><semicolon>xs```<ret>"
          _render-markdown-emit-static codeblock-start
        }
        evaluate-commands -itersel -draft %{
          execute-keys "<a-:><semicolon>xs```<ret>"
          _render-markdown-emit-static codeblock-end
        }
      }
    }
  }

  define-command -hidden _render-markdown-match-lists %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*>?\h*>*(-\h\[[x<space>]\]|[-*+]\h)<ret>s(-\h\[[x<space>]\]|[-*+]\h)<ret>_L"
        _render-markdown-handle list
      }
    }
  }

  define-command -hidden _render-markdown-match-hrules %{
    evaluate-commands -draft %{
      execute-keys "gtGbx"
      try %{
        execute-keys "s^\h*>?\h*>*(-{4,}|_{4,}|\*{4,})\n<ret>s[-_*]+<ret>"
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
        execute-keys "s(?<lt>!\w)(?<lt>!\\)(?:`[^`\n]+`|(?<lt>!\*)\*\*[^*\n]+\*\*(?!\*)|(?<lt>!_)__[^_\n]+__(?!_)|~~[^~\n]+~~|(?<lt>!\*)\*[^*\n]+\*(?!\*)|(?<lt>!_)_[^_\n]+_(?!_))(?!\w)<ret>"
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

  define-command -hidden _render-markdown-update %{
    set-option window _render_markdown_bare_ranges
    set-option global _render_markdown_consumed_lines
    evaluate-commands -draft %{
      # matcher table: ordered, one command per feature, in original order;
      # each matcher re-selects the whole buffer (gtGbx) before its search
      _render-markdown-match-headings
      _render-markdown-match-codeblocks
      _render-markdown-match-lists
      _render-markdown-match-hrules
      _render-markdown-match-blockquotes
      _render-markdown-match-links
      _render-markdown-match-emphasis
    }
    set-option window _render_markdown_ranges %val{timestamp} %opt{_render_markdown_bare_ranges}
  }
}

require-module render-markdown
