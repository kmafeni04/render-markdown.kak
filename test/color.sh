#!/usr/bin/env sh
# Shared coloring helpers for the test scripts.
#
# Color policy (standard conventions):
#   NO_COLOR    set (non-empty) -> never color (veto)
#   FORCE_COLOR set (non-empty) -> always color, unless NO_COLOR is set
#   otherwise                   -> color only when stdout is a tty
#
# Sourcing runs cm_init_color immediately, so source at top level (not in a
# command substitution); $cm_color_enabled is inherited by the cm_* subshells.

# cm_init_color: decide color-on/off once.
cm_color_enabled=no
cm_init_color() {
  cm_color_enabled=no
  if [ -n "${NO_COLOR:-}" ]; then
    cm_color_enabled=no
  elif [ -n "${FORCE_COLOR:-}" ]; then
    cm_color_enabled=yes
  elif [ -t 1 ]; then
    cm_color_enabled=yes
  fi
}

cm_init_color

# cm_color <code> <text>: wrap text in the ANSI SGR code when enabled,
# otherwise echo it unchanged.
cm_color() {
  if [ "$cm_color_enabled" = yes ]; then
    printf '\033[%sm%s\033[0m' "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

cm_red() { cm_color 31 "$1"; }
cm_green() { cm_color 32 "$1"; }
cm_yellow() { cm_color 33 "$1"; }
cm_bold() { cm_color 1 "$1"; }
