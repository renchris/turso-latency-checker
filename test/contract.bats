#!/usr/bin/env bats
# Today's contract, kept by decision packet ad226c7513ea: a finished run exits 0,
# and the piped table, failure block and fastest line stay on stdout. If that packet
# is answered "change", the contract-changing wave replaces these guards.

load helpers

@test "K-T1 kept contract: a finished run exits 0 even when regions failed" {
  export STUB_CURL_FAIL="bog:3 arn:3"
  run_cli
  [ "$status" -eq 0 ]
  unset STUB_CURL_FAIL
  export STUB_CURL_FAIL_ALL=3
  run_cli
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -Fxq "No successful connections to any region."
}

@test "K-T2 kept contract: help lists the exit codes" {
  run_cli --help
  [[ $output == *"Exits 0 after a finished run, even when regions failed; 1 when it can't"* ]]
  [[ $output == *"start; 2 on a usage error."* ]]
  [ -z "$(printf '%s\n' "$output" | LC_ALL=C tr -d '\200-\277' | awk 'length>80')" ]
}

@test "K-T3 kept contract: piped stdout keeps the padded table, failures and fastest line" {
  export STUB_CURL_FAIL="bog:3" STUB_CURL_TIMES="ams:0.010"
  run_cli
  [[ ${lines[0]} == "ID      LOCATION "* ]]
  printf '%s\n' "$output" | grep -q '^- bog '
  printf '%s\n' "$output" | grep -Fxq 'Fastest region: ams (Amsterdam, Netherlands) - 10ms (Gateway Region)'
  [[ $stderr != *"Fastest region"* ]]
}
