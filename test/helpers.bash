# Shared setup for the turso-latency-checker bats suite. Tests never reach the
# network: the stub curl comes first on PATH, and a stub miss hits a dead proxy.
bats_require_minimum_version 1.5.0

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../turso-latency-checker.sh"
  TLC_BASH=${TLC_BASH:-/bin/bash}
  export TLC_BASH
  PATH="$BATS_TEST_DIRNAME/fixtures/bin:$PATH"
  TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$TMPDIR"
  STUB_CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
  export PATH TMPDIR STUB_CURL_LOG
  export http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9
  export HTTPS_PROXY=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9
  export TERM=xterm-256color LC_ALL=en_US.UTF-8
  unset NO_COLOR FORCE_COLOR CI CLAUDECODE TURSO_LATENCY_ACCESSIBLE TURSO_LATENCY_COMPAT_TABLE COLUMNS
}

run_cli() {
  run --separate-stderr "$TLC_BASH" "$SCRIPT" "$@"
}

# A no-op until a compat switch exists; keeps these tests valid if one lands.
run_cli_1x() {
  TURSO_LATENCY_COMPAT_TABLE=1 run_cli "$@"
}

# BSD script(1) puts ^D\b\b at the start and turns \n into \r\n. Spinner \r bytes
# are not line-final, so they survive this.
normalize_tty() {
  output=$(printf '%s' "$output" | LC_ALL=C sed -e $'s/\\^D\b\b//g' -e $'s/\r$//')
  lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done <<<"$output"
}

run_tty() {
  run script -q /dev/null "$TLC_BASH" "$SCRIPT" "$@" </dev/null
  normalize_tty
}

# Same, with the child's stdin not a terminal.
run_tty_stdin_piped() {
  # shellcheck disable=SC2016  # expanded by the child shell
  run script -q /dev/null "$TLC_BASH" -c 'exec "$1" "$2" </dev/null' _ "$TLC_BASH" "$SCRIPT" </dev/null
  normalize_tty
}

run_tty_cols() {
  local cols=$1
  shift
  # shellcheck disable=SC2016  # expanded by the child shell
  run script -q /dev/null "$TLC_BASH" -c 'stty cols "$1" rows 60; b=$2; s=$3; shift 3; exec "$b" "$s" "$@"' _ "$cols" "$TLC_BASH" "$SCRIPT" "$@" </dev/null
  normalize_tty
}

strip_ansi() {
  LC_ALL=C sed $'s/\033\\[[0-9;]*[mK]//g'
}

# ANSI-free text with each line reduced to what remains after its last \r.
tty_text() {
  printf '%s\n' "$output" | strip_ansi | LC_ALL=C sed $'s/.*\r//'
}

display_columns() {
  printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

assert_one_json_line() {
  [ "$(printf '%s\n' "$1" | wc -l | tr -d ' ')" = 1 ] && printf '%s\n' "$1" | jq -e . >/dev/null
}

# Parses argv with the real parser and runs nothing; succeeds when argv is valid.
parse_only() {
  (
    set +e
    # shellcheck disable=SC1090
    source "$SCRIPT"
    parse_args "$@"
    [ -z "$USAGE_ERR" ] && [ -z "${USAGE_ISSUES:-}" ]
  )
}

assert_no_probes() {
  [ ! -s "$STUB_CURL_LOG" ] || return 1
  [ -z "$(find "$TMPDIR" -mindepth 1)" ] || return 1
}

# Lines of stdout that are table rows for a region code, such as "ams ...".
table_rows() {
  printf '%s\n' "$output" | grep -E '^[a-z]{3} ' || true
}

# Starts the CLI in the background with fds detached from bats; sets CLI_PID.
start_cli() {
  "$TLC_BASH" "$SCRIPT" "$@" >/dev/null 2>"$BATS_TEST_TMPDIR/stderr" 3>&- &
  export CLI_PID=$!
}

wait_until() {
  local tenths=$1 i=0
  shift
  while [ "$i" -lt "$tenths" ]; do
    if "$@"; then return 0; fi
    sleep 0.1
    i=$((i + 1))
  done
  return 1
}

pid_count_is() {
  [ -f "$1" ] && [ "$(wc -l <"$1" | tr -d ' ')" -ge "$2" ]
}

no_pids_alive() {
  local pid
  while IFS= read -r pid; do
    if kill -0 "$pid" 2>/dev/null; then return 1; fi
  done <"$1"
}
