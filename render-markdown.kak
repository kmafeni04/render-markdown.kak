provide-module render-markdown %{
  declare-option -hidden str-list _render_markdown_bare_ranges
  declare-option -hidden range-specs _render_markdown_ranges

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

  declare-option str render_markdown_horizontal_rule "{rgb:4F4F4F+f}──────────────────"

  declare-option str render_markdown_blockquote "{rgb:4F4F4F+f}▋ "

  declare-option str render_markdown_link_image "{blue+fu@Default} "
  declare-option str render_markdown_link_web "{blue+fu@Default}󰖟 "
  declare-option str render_markdown_link_link "{blue+fu@Default} "
  declare-option str render_markdown_link_mail "{blue+fu@Default}󰇮 "

  declare-option str render_markdown_strikethrough "{+s@Default}"
  declare-option str render_markdown_italics "{+i@Default}"
  declare-option str render_markdown_bold "{+b@Default}"
  declare-option str render_markdown_inline_code "{cyan,black+f}"


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
    try %{
      evaluate-commands -draft %{
        execute-keys "gtGbx"

        # Headings
        evaluate-commands -draft %{
          try %{
            execute-keys "s^>?\h*#+\s<ret>s#+<ret>Gl"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  exit
                fi
                heading_level="$(printf '%s' "$kak_selection" | grep -o '^#*' | wc -m)"
                heading_level=$((heading_level - 1))
                content="$(printf '%s' "$kak_selection" | sed -E "s/^#+//;s/'/\'\'/g")"

                heading_range="$kak_selection_desc|"
                if [ $heading_level -gt 6 ]; then
                  exit
                elif [ $heading_level -eq 6 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_6}"
                elif [ $heading_level -eq 5 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_5}"
                elif [ $heading_level -eq 4 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_4}"
                elif [ $heading_level -eq 3 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_3}"
                elif [ $heading_level -eq 2 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_2}"
                elif [ $heading_level -eq 1 ]; then
                  heading_range="${heading_range}${kak_opt_render_markdown_heading_1}"
                fi
                heading_range="${heading_range}${content}"

                printf "set-option -add window _render_markdown_bare_ranges '%s'\n" "$heading_range"
              }
            }
          }
        }

        # Code-blocks
        evaluate-commands -draft %{
          try %{
            execute-keys "%%s```[\w+-]*\n((?:(?!```).)*)\n[^\n]*```<ret>" # '%' as ``` will break if start and end are not both in view
            evaluate-commands -itersel -draft %{
              execute-keys "<a-:><a-semicolon><semicolon>xs```<ret>"
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_codeblock_start}"
            }
            evaluate-commands -itersel -draft %{
              execute-keys "<a-:><semicolon>xs```<ret>"
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_codeblock_end}"
            }
          }
        }

        # Checkboxes and list items
        evaluate-commands -draft %{
          try %{
            execute-keys "s^\h*>?\h*>*(-\h\[[x<space>]\]|[-*+]\h)<ret>s(-\h\[[x<space>]\]|[-*+]\h)<ret>_L"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  exit
                fi
                if [ -n "$(printf '%s' "$kak_selection" | grep -Po -- '-\s\[')" ]; then
                  if [ -n "$(printf '%s' "$kak_selection" | grep -o x)" ]; then
                    printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                      "$kak_selection_desc|$kak_opt_render_markdown_checkbox_checked"
                  else
                    printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                      "$kak_selection_desc|$kak_opt_render_markdown_checkbox_unchecked"
                  fi
                else
                  printf "set-option -add window _render_markdown_bare_ranges '%s'\n" "$kak_selection_desc|$kak_opt_render_markdown_bullet"
                fi
              }
            }
          }
        }

        # Horizontal Ruules
        evaluate-commands -draft %{
          try %{
            execute-keys "s^\h*>?\h*>*----*\n<ret>s-+<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  printf "fail\n"
                fi
              }
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_horizontal_rule}"
            }
          }
        }
        evaluate-commands -draft %{
          try %{
            execute-keys "s^\h*>?\h*>*____*\n<ret>s_+<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  printf "fail\n"
                fi
              }
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_horizontal_rule}"
            }
          }
        }
        evaluate-commands -draft %{
          try %{
            execute-keys "s^\h*>?\h*>*\*\*\*\**\n<ret>s\*+<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  printf "fail\n"
                fi
              }
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_horizontal_rule}"
            }
          }
        }

        # Block Quotes
        evaluate-commands -draft %{
          try %{
            execute-keys "s^\h*<gt><ret>Gls<gt>\h<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  printf "fail\n"
                fi
              }
              set-option -add window _render_markdown_bare_ranges "%val{selection_desc}|%opt{render_markdown_blockquote}"
            }
          }
        }


        # Links
        evaluate-commands -draft %{
          try %{
            execute-keys "s!?\[[^\[]+\]\([^\(]+\)<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  exit
                fi
                content="$(printf '%s' "$kak_selection" | grep -Po '\[.+\]' | sed "s/^\[//;s/\]$//;s/'/\'\'/g")"
                if [ "$(printf '%s' "$kak_selection" | cut -c 1)" = "!" ]; then
                  printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                    "$kak_selection_desc|${kak_opt_render_markdown_link_image}${content}"
                elif [ -n "$(printf '%s' "$kak_selection" | grep -Po '\(https?://' )" ]; then
                  printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                    "$kak_selection_desc|${kak_opt_render_markdown_link_web}${content}"
                else
                  printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                    "$kak_selection_desc|${kak_opt_render_markdown_link_link}${content}"
                fi
              }
            }
          }
        }
        evaluate-commands -draft %{
          try %{
            execute-keys "s!?\[[^\[]+\]\[[^\[]+\]<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  exit
                fi
                content="$(printf '%s' "$kak_selection" | grep -Po '\[.+\]\[' | sed "s/^\[//g;s/\]\[$//g;s/'/\'\'/g")"
                printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                  "$kak_selection_desc|${kak_opt_render_markdown_link_link}${content}"
              }
            }
          }
        }
        evaluate-commands -draft %{
          try %{
            execute-keys "s<lt>\S+@\S+\.[^\n]+<gt><ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              evaluate-commands %sh{
                if [ -n "$kak_main_reg_i" ]; then
                  exit
                fi
                content="$(printf '%s' "$kak_selection" | sed "s/^<//;s/>$//;s/'/\'\'/g" )"
                printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                  "$kak_selection_desc|${kak_opt_render_markdown_link_mail}${content}"
              }
            }
          }
        }

        # Strikethrough, Italics, Bold and Inline code
        evaluate-commands -draft %{
          try %{
            execute-keys "s(?<lt>!\\)(?:`[^`\n]+`|\*\*[^*\n]+\*\*|__[^_\n]+__|~~[^~\n]+~~|\*[^*\n]+\*|_[^_\n]+_)<ret>"
            evaluate-commands -save-regs 'i' -itersel %{
              set-register i ''
              evaluate-commands -draft %{
                try %{
                  execute-keys "<a-a>c```\w,```<ret><a-:><a-semicolon><semicolon>xs^\h*```\w<ret>"
                  evaluate-commands %sh{
                    if ! printf '%s' "$kak_selection" | grep 'markdown'; then
                      printf "set-register i 'inside'\n"
                    fi
                  }
                }
              }
              try %{
                evaluate-commands %sh{
                  if [ -n "$kak_main_reg_i" ]; then
                    exit
                  fi
                  start="${kak_selection:0:1}"
                  end="${kak_selection: -1}"
                  if [ "$start" = "$end" ]; then
                    content="$(printf '%s' "$kak_selection" | sed "s/'/\'\'/g")"
                    case "$start" in
                      "~")
                        content="$(printf '%s' "$content" | sed 's/~//g')"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_strikethrough}${content}"
                        ;;
                      "\`")
                        content="${content//\`/}"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_inline_code}${content}"
                        ;;
                      "_")
                        if [ ${content:0:2} = "__" ]; then
                          content="${content//\_/}"
                          printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                            "$kak_selection_desc|${kak_opt_render_markdown_italics}${content}"
                        else
                          content="${content//\_/}"
                          printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                            "$kak_selection_desc|${kak_opt_render_markdown_bold}${content}"
                        fi
                        ;;
                      "*")
                        if [ ${content:0:2} = "**" ]; then
                          content="${content//\*/}"
                          printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                            "$kak_selection_desc|${kak_opt_render_markdown_italics}${content}"
                        else
                          content="${content//\*/}"
                          printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                            "$kak_selection_desc|${kak_opt_render_markdown_bold}${content}"
                        fi
                        ;;
                    esac
                    printf "fail\n"
                  else
                    printf "execute-keys '<a-:><a-semicolon><semicolon>'\n"
                    case "$start" in
                      "\`")
                        printf "execute-keys 'l<a-a>g'\n"
                        ;;
                      "~")
                        printf "execute-keys 'l<a-a>c~,~<ret>\n"
                        ;;
                      "_")
                        printf "execute-keys 'l<a-a>c_,_<ret>\n"
                        ;;
                      "*")
                        printf "execute-keys 'l<a-a>c\*,\*<ret>\n"
                        ;;
                    esac
                    printf "execute-keys '<a-:><a-semicolon>'\n"
                  fi
                }
                evaluate-commands %sh{
                  start="${kak_selection:0:1}"
                  content="$(printf '%s' "$kak_selection" | sed "s/'/\'\'/g")"
                  case "$start" in
                    "~")
                      content="$(printf '%s' "$content" | sed 's/~//g')"
                      printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                        "$kak_selection_desc|${kak_opt_render_markdown_strikethrough}${content}"
                      ;;
                    "\`")
                      content="${content//\`/}"
                      printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                        "$kak_selection_desc|${kak_opt_render_markdown_inline_code}${content}"
                      ;;
                    "_")
                      if [ ${content:0:2} = "__" ]; then
                        content="${content//\_/}"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_italics}${content}"
                      else
                        content="${content//\_/}"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_bold}${content}"
                      fi
                      ;;
                    "*")
                      if [ ${content:0:2} = "**" ]; then
                        content="${content//\*/}"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_italics}${content}"
                      else
                        content="${content//\*/}"
                        printf "set-option -add window _render_markdown_bare_ranges '%s'\n" \
                          "$kak_selection_desc|${kak_opt_render_markdown_bold}${content}"
                      fi
                      ;;
                  esac
                }
              }
            }
          }
        }
      }
      set-option window _render_markdown_ranges %val{timestamp} %opt{_render_markdown_bare_ranges}
    }
  }
}

require-module render-markdown
