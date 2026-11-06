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
  wait_until 50 temp_dir_exists || rc=1
  [ ! -e "/tmp/turso_latency_$CLI_PID" ] || rc=2
  wait "$CLI_PID" || true
  [ "$rc" -eq 0 ]
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
}

@test "A-T8 SIGTERM exits 143, removes temp dir, leaves no probe processes" {
  export STUB_CURL_SLEEP=30 STUB_CURL_PIDS="$BATS_TEST_TMPDIR/pids"
  start_cli --timeout 30
  wait_until 50 pid_count_is "$STUB_CURL_PIDS" 35
  temp_dir_exists
  kill -TERM "$CLI_PID"
  rc=0
  wait "$CLI_PID" || rc=$?
  [ "$rc" -eq 143 ]
  [ -z "$(find "$TMPDIR" -mindepth 1)" ]
  wait_until 20 no_pids_alive "$STUB_CURL_PIDS"
}

@test "A-T9 SIGINT exits 130 and prints Canceled." {
  export STUB_CURL_SLEEP=30 STUB_CURL_PIDS="$BATS_TEST_TMPDIR/pids"
  e="$BATS_TEST_TMPDIR/err"
  python3 -c 'import os,signal,sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' \
    "$TLC_BASH" "$SCRIPT" --timeout 30 >/dev/null 2>"$e" 3>&- &
  pid=$!
  wait_until 50 pid_count_is "$STUB_CURL_PIDS" 35
  kill -INT "$pid"
  rc=0
  wait "$pid" || rc=$?
  [ "$rc" -eq 130 ]
  [ "$(tail -n 2 "$e" | sed -n 1p)" = "Canceled." ]
  [ "$(tail -n 1 "$e")" = "Nothing was changed." ]
  ! tail -n 2 "$e" | grep -q $'\r'
  wait_until 20 no_pids_alive "$STUB_CURL_PIDS"
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
