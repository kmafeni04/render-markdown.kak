#!/usr/bin/env sh
# Helpers for driving a headless kakoune via its built-in json ui: a client
# with a real window but no terminal needed. Sourced by run-fixture.sh and
# smoke.sh. The json ui reads json-rpc from stdin and writes draw events to
# stdout; the client exits when stdin hits EOF.
#
# usage:
#   kak_json_start <session> <workdir> <init commands>
#   kak_json_key <key>            # e.g. j
#   kak_json_stop
#   kak_json_error <workdir>      # fail if kak wrote to its stderr

KAK_PID=
kak_json_start() { # session work init
  mkfifo "$2/in"
  kak -n -s "$1" -ui json -e "$3" < "$2/in" > "$2/out.json" 2> "$2/err" &
  KAK_PID=$!
  exec 3> "$2/in"   # hold stdin open; closed by kak_json_stop
}

kak_json_key() { # key
  printf '%s\n' "{\"jsonrpc\":\"2.0\",\"method\":\"keys\",\"params\":[\"$1\"]}" >&3
}

kak_json_stop() {
  exec 3>&-
  wait "$KAK_PID" 2>/dev/null || true
}

kak_json_error() { # work: prints kak stderr and fails if any
  if [ -s "$1/err" ]; then
    cat "$1/err" >&2
    return 1
  fi
  return 0
}