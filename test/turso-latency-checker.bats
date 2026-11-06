#!/usr/bin/env bats
# Waves A and B. Failure-path exit codes for a finished run are not asserted here:
# they are a documented contract guarded in test/contract.bats.

load helpers

@test "A-T1 help: --help, -h and help print usage to stdout, exit 0, no probes" {
  for arg in --help -h help; do
    run_cli "$arg"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Usage: turso-latency-checker [options]" ]
    [ -z "$stderr" ]
    assert_no_probes
  done
}

@test "A-T2 help wins over --version and over unknown options" {
  for args in "--version --help" "--bogus --help"; do
    # shellcheck disable=SC2086
    run_cli $args
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "Usage: turso-latency-checker [options]" ]
  done
}

@test "A-T3 version: -v and --version print only the version" {
  expected=$(sed -n 's/^VERSION=\([0-9.]*\).*/\1/p' "$SCRIPT")
  [[ $expected =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  if [ -s "$BATS_TEST_DIRNAME/../package.json" ]; then
    [ "$expected" = "$(jq -r .version "$BATS_TEST_DIRNAME/../package.json")" ]
  fi
  for arg in -v --version; do
    run_cli "$arg"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected" ]
    assert_no_probes
  done
}

@test "A-T4 unknown option exits 2 before any probe" {
  run_cli --jsno
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "${stderr_lines[0]}" = "Error: Unknown option --jsno for turso-latency-checker." ]
  [[ $stderr == *$'\n    turso-latency-checker --help'* ]]
  assert_no_probes
}

@test "A-T5 unexpected positional exits 2" {
  run_cli foo
  [ "$status" -eq 2 ]
  [[ $stderr == *"Unknown command foo for turso-latency-checker."* ]]
  run_cli -- foo
  [ "$status" -eq 2 ]
  [[ $stderr == *"Unknown command foo for turso-latency-checker."* ]]
  assert_no_probes
}

@test "A-T6 --timeout validation" {
  run_cli --timeout 0
  [ "$status" -eq 2 ]
  [[ $stderr == *--timeout* ]]
  run_cli --timeout abc
  [ "$status" -eq 2 ]
  [[ $stderr == *--timeout* ]]
  run_cli --timeout
  [ "$status" -eq 2 ]
  [[ $stderr == *--timeout* ]]
  assert_no_probes

  run_cli --timeout 5s
  [ "$status" -eq 0 ]
  [ -s "$STUB_CURL_LOG" ]
  [ "$(grep -c -- '--max-time 5 ' "$STUB_CURL_LOG")" = "$(wc -l <"$STUB_CURL_LOG" | tr -d ' ')" ]

  : >"$STUB_CURL_LOG"
  run_cli --timeout=1.5
  [ "$status" -eq 0 ]
  [ -s "$STUB_CURL_LOG" ]
  [ "$(grep -c -- '--max-time 1.5 ' "$STUB_CURL_LOG")" = "$(wc -l <"$STUB_CURL_LOG" | tr -d ' ')" ]
}

temp_dir_exists() {
  compgen -G "$TMPDIR/turso-latency.*" >/dev/null
}

@test "A-T7 temp dir: under TMPDIR via mktemp, removed after the run" {
  export STUB_CURL_SLEEP=1
  start_cli
  rc=0
  wait_until 200 temp_dir_exists || rc=1
  [ ! -e "/tmp/turso_latency_$CLI_PID" ] || rc=2
  wait "$CLI_PID" || true
  [ "$rc" -eq 0 ]
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
}

@test "A-T8 SIGTERM exits 143, removes temp dir, leaves no probe processes" {
  export STUB_CURL_SLEEP=30 STUB_CURL_PIDS="$BATS_TEST_TMPDIR/pids"
  start_cli --timeout 30
  wait_until 200 pid_count_is "$STUB_CURL_PIDS" 35
  temp_dir_exists
  kill -TERM "$CLI_PID"
  rc=0
  wait "$CLI_PID" || rc=$?
  [ "$rc" -eq 143 ]
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
  wait_until 100 no_pids_alive "$STUB_CURL_PIDS"
}

@test "A-T9 SIGINT exits 130 and prints Canceled." {
  export STUB_CURL_SLEEP=30 STUB_CURL_PIDS="$BATS_TEST_TMPDIR/pids"
  e="$BATS_TEST_TMPDIR/err"
  python3 -c 'import os,signal,sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' \
    "$TLC_BASH" "$SCRIPT" --timeout 30 >/dev/null 2>"$e" 3>&- &
  pid=$!
  wait_until 200 pid_count_is "$STUB_CURL_PIDS" 35
  kill -INT "$pid"
  rc=0
  wait "$pid" || rc=$?
  [ "$rc" -eq 130 ]
  [ "$(tail -n 2 "$e" | sed -n 1p)" = "Canceled." ]
  [ "$(tail -n 1 "$e")" = "Nothing was changed." ]
  ! tail -n 2 "$e" | grep -q $'\r'
  wait_until 100 no_pids_alive "$STUB_CURL_PIDS"
}

@test "A-T10 closed stdout ends quietly with exit 0" {
  export STUB_CURL_SLEEP=0.2
  e="$BATS_TEST_TMPDIR/err"
  "$TLC_BASH" "$SCRIPT" 2>"$e" | true
  rc=${PIPESTATUS[0]}
  [ "$rc" -eq 0 ]
  ! grep -q 'Broken pipe' "$e"
  ! grep -q 'write error' "$e"
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
}

# Every command the CLI prints: help examples, README code-block lines and the
# usage-error recovery. Prints one per line.
printed_commands() {
  "$TLC_BASH" "$SCRIPT" --help | awk '/^Examples:/{on=1;next} /^[A-Z][a-z]+( more)?:/{on=0} on' |
    sed -n 's/^    \(turso-latency-checker\)/\1/p'
  awk '/^```/{fence=!fence;next} fence' "$BATS_TEST_DIRNAME/../README.md" | grep '^turso-latency-checker' || true
  "$TLC_BASH" "$SCRIPT" --jsno 2>&1 >/dev/null | sed -n 's/^    \(turso-latency-checker\)/\1/p'
}

@test "A-T11 every help example and printed self-command parses without running (R100, R393)" {
  checked=0
  while IFS= read -r command; do
    read -ra argv <<<"$command"
    parse_only "${argv[@]:1}"
    checked=$((checked + 1))
  done < <(printed_commands)
  [ "$checked" -ge 2 ]
  [ ! -s "$STUB_CURL_LOG" ]
}

@test "A-T12 entry points, short/long forms, repeats and booleans (R392, R393, R065, R068, R069, R087)" {
  run_cli --help
  long_help=$output
  [[ $long_help == *$'\nOptions:\n'*$'\nExamples:\n'*$'\nNotes:\n'*$'\nLearn more:'* ]]
  [ "${lines[0]}" = "Usage: turso-latency-checker [options]" ]
  run_cli -h
  [ "$output" = "$long_help" ]
  run_cli help
  [ "$output" = "$long_help" ]
  run_cli -v
  version=$output
  run_cli --version
  [ "$output" = "$version" ]

  from_help=$(printf '%s\n' "$long_help" | awk '/^Options:/{on=1;next} /^$/{on=0} on' | sed -E 's/^ +(-[a-z], )? *--([a-z-]+).*/\2/')
  from_opts=$(
    # shellcheck disable=SC1090
    source "$SCRIPT"
    printf '%s\n' "$OPTS" | cut -d'|' -f1
  )
  [ -n "$from_opts" ]
  [ "$from_help" = "$from_opts" ]
  [ "$from_opts" = "$(printf '%s\n' "$from_opts" | LC_ALL=C sort)" ]

  run_cli --timeout 1s --timeout 2s
  [ "$status" -eq 0 ]
  [ "$(grep -c -- '--max-time 2 ' "$STUB_CURL_LOG")" = "$(wc -l <"$STUB_CURL_LOG" | tr -d ' ')" ]

  # A prefix never matches. With a value after it, both words are reported as rows.
  : >"$STUB_CURL_LOG"
  run_cli --time 5s
  [ "$status" -eq 2 ]
  [[ $stderr == *"--time: Unknown option."* ]]
  run_cli --time=5s
  [ "$status" -eq 2 ]
  [[ $stderr == *"Unknown option --time=5s"* ]]
  [ ! -s "$STUB_CURL_LOG" ]

  run_cli --no-color=true
  [ "$status" -eq 0 ]
  run_cli --no-color=false
  [ "$status" -eq 0 ]
  run_cli --no-color=maybe
  [ "$status" -eq 2 ]
  run_cli --timeout=
  [ "$status" -eq 2 ]
  run_cli --timeout ''
  [ "$status" -eq 2 ]
}

@test "A-T13 every usage problem is reported at once (R302)" {
  run_cli --timeout 0 --jsno foo
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "${stderr_lines[0]}" = "Error: Can't measure latency. 3 inputs are invalid." ]
  [[ ${stderr_lines[1]} == "  --timeout 0: "* ]]
  [[ ${stderr_lines[2]} == "  --jsno: "* ]]
  [[ ${stderr_lines[3]} == "  foo: "* ]]
  [[ $stderr == *"See all options:"* ]]
  assert_no_probes

  run_cli --a --b --c --d --e --f --g
  [ "$status" -eq 2 ]
  [ "${stderr_lines[0]}" = "Error: Can't measure latency. 7 inputs are invalid." ]
  [ "$(printf '%s\n' "$stderr" | grep -c '^  --[a-g]: ')" -eq 5 ]
  [ "${stderr_lines[6]}" = "  and 2 more" ]
  assert_no_probes
}

@test "A-T14 mode, theme and color checks live only in the helper block (R116, R408, R412)" {
  grep -q '^# ---- cli helpers' "$SCRIPT"
  ! sed '/^# ---- cli helpers/,/^# ---- end cli helpers ----/d' "$SCRIPT" |
    grep -nE '\[ -t [012] \]|\$\{?(CI|CLAUDECODE|TERM)([^A-Za-z0-9_]|$)|\\033\['
}

@test "A-T15 help fits 80 columns (R095)" {
  run_cli --help
  [ "${lines[0]}" = "Usage: turso-latency-checker [options]" ]
  [ -z "$(printf '%s\n' "$output" | LC_ALL=C tr -d '\200-\277' | awk 'length>80')" ]
}

@test "A-T16 every command the CLI prints uses long options (Round 2 re-check; R099, R047)" {
  checked=0
  while IFS= read -r command; do
    read -ra argv <<<"$command"
    for word in "${argv[@]}"; do
      [[ ! $word =~ ^-[a-zA-Z]$ ]]
    done
    checked=$((checked + 1))
  done < <(printed_commands)
  [ "$checked" -ge 2 ]
  ! grep -nE '"curl -[a-zA-Z]' "$SCRIPT"
}

@test "B1-T1 probe: curl failure is reported as failed, never as a latency" {
  export STUB_CURL_FAIL="bog:28 gru:7"
  run_cli_1x
  [ -s "$STUB_CURL_LOG" ]
  ! printf '%s\n' "$output" | grep -qE '^(bog|gru) '
  printf '%s\n' "$output" | grep -q '^- bog '
  printf '%s\n' "$output" | grep -q '^- gru '
  [ "$(table_rows | wc -l | tr -d ' ')" -eq 33 ]
}

@test "B1-T2 probe: sub-millisecond time renders as 0ms, never blank" {
  export STUB_CURL_TIME=0.000500
  run_cli_1x
  [ -s "$STUB_CURL_LOG" ]
  [ "$(table_rows | wc -l | tr -d ' ')" -eq 35 ]
  [ "$(table_rows | grep -cE ' 0ms( |$)')" -eq 35 ]
}

@test "B1-T3 probe: works when bc is missing" {
  export STUB_CURL_TIME=0.000500
  PATH="$BATS_TEST_DIRNAME/fixtures/nobc:$PATH"
  run_cli_1x
  [ "$(table_rows | wc -l | tr -d ' ')" -eq 35 ]
  [ "$(table_rows | grep -cE ' 0ms( |$)')" -eq 35 ]
  ! grep -qw bc "$SCRIPT"
}

@test "B2-T1 wait: bounded when a probe hangs" {
  export STUB_CURL_HANG=ams
  SECONDS=0
  TURSO_LATENCY_COMPAT_TABLE=1 run --separate-stderr timeout 40 "$TLC_BASH" "$SCRIPT" --timeout 1
  [ "$SECONDS" -lt 35 ]
  printf '%s\n' "$output" | grep -q '^- ams (Amsterdam, Netherlands): no result within'
}

@test "B2-T2 wait: unwritable TMPDIR fails fast" {
  TMPDIR=/nonexistent/x run --separate-stderr timeout 10 "$TLC_BASH" "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "Error: Couldn't create a temp directory in /nonexistent/x." ]
}

@test "B2-T3 results: never written with a bare redirect" {
  ! grep -nE '> *"\$TEMP_DIR/(res/)?\$loc' "$SCRIPT"
  grep -q 'atomic_write' "$SCRIPT"
  ! grep -n 'while true' "$SCRIPT"
}

@test "B3-T1 streams: piped stdout holds no banner, spinner or carriage return" {
  run_cli_1x
  [[ $output != *$'\r'* ]]
  [[ $output != *Measuring* ]]
  [[ ${lines[0]} == "ID      LOCATION "* ]]
  [[ $stderr == *"Measuring latency to 35 Turso regions via region.turso.io:8080..."* ]]
}

@test "B3-T2 contract: the 1.x piped header and rows are unchanged (Round 2; R384, R402)" {
  export STUB_CURL_TIME=0.050
  run_cli_1x
  stripped=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
  printf '%s\n' "$stripped" | grep -Fxq "$(printf '%-6s  %-36s  %11s  %s' ID LOCATION LATENCY GATEWAY)"
  gateways=" ams cdg dfw fra hkg iad lax lhr nrt ord scl sea sin sjc syd yyz "
  regions=0
  while IFS='|' read -r code name; do
    mark=' '
    [[ $gateways != *" $code "* ]] || mark='✓'
    # 1.x padded by bytes, with one extra space for the three non-ASCII names.
    case "$code" in
      gru | bog | qro) row=$(LC_ALL=C printf '%-6s  %-36s   %11s  %s' "$code" "$name" 50ms "$mark") ;;
      *) row=$(LC_ALL=C printf '%-6s  %-36s  %11s  %s' "$code" "$name" 50ms "$mark") ;;
    esac
    printf '%s\n' "$stripped" | grep -Fxq -- "$row"
    regions=$((regions + 1))
  done < <(sed -n 's/^ *"\([a-z]\{3\}\)") echo "\(.*\)" ;;$/\1|\2/p' "$SCRIPT")
  [ "$regions" -eq 35 ]
  printf '%s\n' "$stripped" | grep -Fxq 'Fastest region: ams (Amsterdam, Netherlands) - 50ms (Gateway Region)'
}

@test "B4-T1 color: no escape bytes when piped, with NO_COLOR, --no-color or TERM=dumb" {
  run_cli
  [[ $output$stderr != *$'\033'* ]]
  NO_COLOR=1 run_cli
  [[ $output$stderr != *$'\033'* ]]
  run_cli --no-color
  [[ $output$stderr != *$'\033'* ]]
  TERM=dumb run_cli
  [[ $output$stderr != *$'\033'* ]]
}

@test "B4-T2 color: only a rich stdout is styled; forced color on a pipe tints only the Error: prefix" {
  export STUB_CURL_TIMES="ams:0.010"
  run_tty
  [[ $output == *$'\033[1m'ams$'\033[0m'* ]]
  [[ $output != *$'\033[1;36m'* ]]
  [[ $output != *$'\033[0;36m'* ]]
  styled_rows=$(tty_text | grep -E '^[a-z]{3} ')
  NO_COLOR=1 run_tty
  [ "$styled_rows" = "$(tty_text | grep -E '^[a-z]{3} ')" ]

  FORCE_COLOR=1 run_cli
  [[ $output != *$'\033'* ]]
  FORCE_COLOR=1 run_cli --jsno
  [ "${stderr_lines[0]}" = $'\033[31mError:\033[0m Unknown option --jsno for turso-latency-checker.' ]
  [ "${stderr_lines[2]}" = "    turso-latency-checker --help" ]

  # The spinner's erase sequence is not color, so this checks color sequences only.
  FORCE_COLOR=0 run_tty
  ! printf '%s\n' "$output" | grep -q $'\033\\[[0-9;]*m'
}

@test "B4-T3 tty: spinner animates on a TTY, not in accessible mode or CI" {
  run_tty
  [[ $output == *$'\r'* ]]
  [[ $output == *⠋* ]]
  TURSO_LATENCY_ACCESSIBLE=1 run_tty
  [[ $output != *$'\r'* ]]
  [[ $output != *⠋* ]]
  CI=1 run_tty
  [[ $output != *$'\r'* ]]
  [[ $output != *⠋* ]]
}

@test "B4-T4 table: non-ASCII names align with ASCII rows" {
  run_cli_1x
  checked=0
  re='^(.*[0-9]ms)'
  while IFS= read -r line; do
    [[ $line =~ $re ]]
    [ "$(display_columns "${BASH_REMATCH[1]}")" -eq 57 ]
    checked=$((checked + 1))
  done < <(printf '%s\n' "$output" | grep -E '^(ams|gru|bog|qro) ')
  [ "$checked" -eq 4 ]
}

@test "B4-T5 gateway: accessible mode prints words, not glyphs" {
  TURSO_LATENCY_ACCESSIBLE=1 run_cli
  printf '%s\n' "$output" | grep -qE '^ams .* yes$'
  printf '%s\n' "$output" | grep -qE '^arn .* no$'
  [[ $output != *✓* ]]
}

@test "B5-T1 retry: a transient failure is retried once and the second timing is kept" {
  export STUB_CURL_FAIL_ONCE="ams:7" STUB_CURL_TIMES="ams:0.020"
  run_cli_1x
  printf '%s\n' "$output" | grep -qE '^ams .* 20ms '
  [ "$(grep -c '^ams ' "$STUB_CURL_LOG")" -eq 2 ]
  [ "$(printf '%s\n' "$stderr" | grep -c '^Retrying automatically\.\.\.$')" -eq 1 ]

  : >"$STUB_CURL_LOG"
  unset STUB_CURL_FAIL_ONCE STUB_CURL_TIMES
  export STUB_CURL_FAIL="arn:3"
  run_cli_1x
  [ "$(grep -c '^arn ' "$STUB_CURL_LOG")" -eq 1 ]
  printf '%s\n' "$output" | grep -q '^- arn '
}

@test "B6-T1 failures: each failed region names its cause" {
  export STUB_CURL_FAIL="bog:28 gru:7 qro:6 scl:56"
  run_cli_1x
  printf '%s\n' "$output" | grep -Fxq "Couldn't reach 4 regions via region.turso.io:8080"
  printf '%s\n' "$output" | grep -q '^- bog (Bogotá, Colombia): timed out after 3s'
  printf '%s\n' "$output" | grep -q '^- gru (São Paulo, Brazil): connection refused'
  printf '%s\n' "$output" | grep -q '^- qro (Querétaro, Mexico): DNS lookup failed'
  printf '%s\n' "$output" | grep -q '^- scl (Santiago, Chile): curl exit 56: Recv failure'
  [[ $stderr == *"Measured 31 of 35 regions. 4 failed."* ]]
}

@test "B6-T2 copy: no banner exclamation, all-caps heading or \"Failed to connect\"" {
  ! grep -nE 'Complete!|RESULTS \(|Failed to connect|=====' "$SCRIPT"
  run_cli_1x
  [ "${stderr_lines[${#stderr_lines[@]}-1]}" = "Measured 35 regions." ]
}

@test "B7-T1 preflight: missing curl fails fast with exit 1" {
  tools="$BATS_TEST_TMPDIR/tools"
  mkdir -p "$tools"
  for tool in awk cat mkdir mktemp mv rm sleep sort tr wc; do
    ln -s "$(command -v "$tool")" "$tools/$tool"
  done
  PATH="$tools" run --separate-stderr "$TLC_BASH" "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "Error: Can't measure latency without curl. Install it and rerun turso-latency-checker." ]
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
}

@test "B7-T2 script parses under bash 3.2 and uses env bash" {
  [ "$(head -1 "$SCRIPT")" = "#!/usr/bin/env bash" ]
  /bin/bash -n "$SCRIPT"
}
