#!/bin/bash

# Turso Latency Checker (Simple Version)
# A simple script to measure latency to all Turso locations

# ---- cli helpers (inline: single-file distribution, see README direct download) ----
PROG=turso-latency-checker
VERSION=1.1.0
PROBE_HOST=region.turso.io:8080
PROBE_URL="http://$PROBE_HOST/"

OPT_HELP=
OPT_VERSION=
OPT_NO_COLOR=
OPT_TIMEOUT=3
USAGE_REASON=
USAGE_ERR=
TEMP_DIR=
PIDS=()

usage_problem() {
  [ -n "$USAGE_ERR" ] && return 0
  USAGE_REASON=$1
  USAGE_ERR=$2
}

# Accepts 5 | 5s | 2.5s | 500ms, positive only; normalizes to seconds for curl.
set_timeout() {
  local value=$1 number=$1 re='^([0-9]+(\.[0-9]+)?|\.[0-9]+)(ms|s)?$'
  if ! [[ $value =~ $re ]]; then
    usage_problem invalid_arguments "Can't use --timeout $value. Use a positive duration, such as 5s."
    return
  fi
  case "$value" in
    *ms) number=$(LC_ALL=C awk -v n="${value%ms}" 'BEGIN { printf "%g", n / 1000 }') ;;
    *s) number=${value%s} ;;
  esac
  case "$number" in
    *[1-9]*) OPT_TIMEOUT=$number ;;
    *) usage_problem invalid_arguments "Can't use --timeout $value. Use a positive duration, such as 5s." ;;
  esac
}

# Records the first usage error and keeps scanning, so -h anywhere still wins.
parse_args() {
  local arg first=1 positional_only=
  while [ $# -gt 0 ]; do
    arg=$1
    shift
    if [ -n "$positional_only" ]; then
      usage_problem unknown_command "Unknown command $arg for $PROG."
      continue
    fi
    case "$arg" in
      help)
        if [ -n "$first" ]; then OPT_HELP=1; else usage_problem unknown_command "Unknown command $arg for $PROG."; fi
        ;;
      -h | --help) OPT_HELP=1 ;;
      -v | --version) OPT_VERSION=1 ;;
      --no-color) OPT_NO_COLOR=1 ;;
      --timeout)
        case "${1:--}" in
          -*) usage_problem invalid_arguments "Can't use --timeout without a value. Use a positive duration, such as 5s." ;;
          *)
            set_timeout "$1"
            shift
            ;;
        esac
        ;;
      --timeout=*) set_timeout "${arg#--timeout=}" ;;
      --) positional_only=1 ;;
      -*) usage_problem unknown_option "Unknown option $arg for $PROG." ;;
      *) usage_problem unknown_command "Unknown command $arg for $PROG." ;;
    esac
    first=
  done
}

# Precedence: --no-color > non-empty NO_COLOR > FORCE_COLOR (0=off, other=on) > a terminal.
color_for() {
  [ -n "$OPT_NO_COLOR" ] && return 1
  [ -n "${NO_COLOR:-}" ] && return 1
  if [ -n "${FORCE_COLOR:-}" ]; then
    [ "$FORCE_COLOR" != 0 ]
    return
  fi
  [ -t "$1" ] && [ "${TERM:-}" != dumb ]
}

resolve_modes() {
  TTY_OUT=
  TTY_ERR=
  RICH_OUT=
  RICH_ERR=
  BOLD=
  RESET=
  E_RED=
  E_CYAN=
  E_RESET=
  if [ -t 1 ]; then TTY_OUT=1; fi
  if [ -t 2 ]; then TTY_ERR=1; fi
  if [ -n "$TTY_OUT" ] && [ "${TERM:-}" != dumb ]; then RICH_OUT=1; fi
  if [ -n "$TTY_ERR" ] && [ "${TERM:-}" != dumb ] && [ -z "${TURSO_LATENCY_ACCESSIBLE:-}" ]; then RICH_ERR=1; fi
  if [ -n "$RICH_OUT" ] && color_for 1; then
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
  fi
  # Forced color on a plain stderr tints only the Error:/Warning: prefix.
  if color_for 2; then
    E_RED=$'\033[31m'
    E_RESET=$'\033[0m'
    if [ -n "$RICH_ERR" ]; then E_CYAN=$'\033[36m'; fi
  fi
  GLYPH_ERR='Error:'
  if [ -n "$RICH_ERR" ]; then GLYPH_ERR='✗'; fi
}

# A closed pipe ends quietly.
outf() {
  local fmt=$1
  shift
  # shellcheck disable=SC2059
  printf "$fmt" "$@" 2>/dev/null || exit 0
}

errf() {
  local fmt=$1
  shift
  # shellcheck disable=SC2059
  printf "$fmt" "$@" >&2
}

stop_spinner() {
  :
}

# die <exit> <reason> <headline> [<recovery-label> <recovery-cmd>]
die() {
  local code=$1 headline=$3 label=${4:-} cmd=${5:-}
  stop_spinner
  errf '%s%s%s %s\n' "$E_RED" "$GLYPH_ERR" "$E_RESET" "$headline"
  if [ -n "$label" ]; then
    errf '\n%s:\n    %s%s%s\n' "$label" "$E_CYAN" "$cmd" "$E_RESET"
  fi
  exit "$code"
}

cleanup() {
  trap - EXIT INT TERM HUP PIPE
  if [ ${#PIDS[@]} -gt 0 ]; then
    kill "${PIDS[@]}" 2>/dev/null
    wait "${PIDS[@]}" 2>/dev/null
  fi
  stop_spinner
  if [ -n "$TEMP_DIR" ]; then rm -rf "${TEMP_DIR:?}"; fi
}

make_temp() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/turso-latency.XXXXXX" 2>/dev/null) ||
    die 1 temp_dir_unavailable "Couldn't create a temp directory in ${TMPDIR:-/tmp}."
  mkdir "$TEMP_DIR/res" "$TEMP_DIR/raw" "$TEMP_DIR/err"
}

# The directory is mktemp-private, so a fixed dot-name is safe.
atomic_write() {
  local dir base
  dir=$(dirname "$1")
  base=$(basename "$1")
  printf '%s\n' "$2" >"$dir/.$base.tmp" && mv -f "$dir/.$base.tmp" "$1"
}

# Code points, independent of the locale; every region name is width-1 per point.
display_width() {
  printf %s "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

pad_to() {
  printf '%s%*s' "$1" $(($2 - $(display_width "$1"))) ''
}
# ---- end cli helpers ----

usage() {
  cat <<'USAGE'
Usage: turso-latency-checker [options]
Measure latency to every Turso region and show the fastest

Options:
  -h, --help                Show this help
      --no-color            Disable color
      --timeout <DURATION>  Time limit for each probe, such as 5s (default: 3s)
  -v, --version             Print the version

Examples:
  Measure every region
    turso-latency-checker

  Give slow links more time
    turso-latency-checker --timeout 10s

Notes:
  Each region gets one plain-HTTP GET to http://region.turso.io:8080/ with a
  fly-prefer-region header; all regions run in parallel.

Learn more: https://github.com/renchris/turso-latency-checker#readme
USAGE
}

# List of Turso locations
LOCATIONS=("ams" "arn" "atl" "bog" "bom" "bos" "cdg" "den" "dfw" "ewr" "eze" "fra" "gdl" "gig" "gru" "hkg" "iad" "jnb" "lax" "lhr" "mad" "mia" "nrt" "ord" "otp" "phx" "qro" "scl" "sea" "sin" "sjc" "syd" "waw" "yul" "yyz")

# Gateway regions
GATEWAY_REGIONS=("ams" "cdg" "dfw" "fra" "hkg" "iad" "lax" "lhr" "nrt" "ord" "scl" "sea" "sin" "sjc" "syd" "yyz")

# Location names mapping for better readability
get_location_name() {
  case "$1" in
    "ams") echo "Amsterdam, Netherlands" ;;
    "arn") echo "Stockholm, Sweden" ;;
    "atl") echo "Atlanta, Georgia (US)" ;;
    "bog") echo "Bogotá, Colombia" ;;
    "bom") echo "Mumbai, India" ;;
    "bos") echo "Boston, Massachusetts (US)" ;;
    "cdg") echo "Paris, France" ;;
    "den") echo "Denver, Colorado (US)" ;;
    "dfw") echo "Dallas, Texas (US)" ;;
    "ewr") echo "Secaucus, NJ (US)" ;;
    "eze") echo "Buenos Aires, Argentina" ;;
    "fra") echo "Frankfurt, Germany" ;;
    "gdl") echo "Guadalajara, Mexico" ;;
    "gig") echo "Rio de Janeiro, Brazil" ;;
    "gru") echo "São Paulo, Brazil" ;;
    "hkg") echo "Hong Kong, Hong Kong" ;;
    "iad") echo "Ashburn, Virginia (US)" ;;
    "jnb") echo "Johannesburg, South Africa" ;;
    "lax") echo "Los Angeles, California (US)" ;;
    "lhr") echo "London, United Kingdom" ;;
    "mad") echo "Madrid, Spain" ;;
    "mia") echo "Miami, Florida (US)" ;;
    "nrt") echo "Tokyo, Japan" ;;
    "ord") echo "Chicago, Illinois (US)" ;;
    "otp") echo "Bucharest, Romania" ;;
    "phx") echo "Phoenix, Arizona (US)" ;;
    "qro") echo "Querétaro, Mexico" ;;
    "scl") echo "Santiago, Chile" ;;
    "sea") echo "Seattle, Washington (US)" ;;
    "sin") echo "Singapore, Singapore" ;;
    "sjc") echo "San Jose, California (US)" ;;
    "syd") echo "Sydney, Australia" ;;
    "waw") echo "Warsaw, Poland" ;;
    "yul") echo "Montreal, Canada" ;;
    "yyz") echo "Toronto, Canada" ;;
    *) echo "Unknown location" ;;
  esac
}

# Function to measure latency for a single location. It runs as a background job
# and owns its curl, so cancellation stops the probe too.
measure_latency() {
  local location="$1" exit_code duration
  trap 'kill "$CPID" 2>/dev/null; exit 143' TERM

  curl -s -o /dev/null -w "%{time_total}" --max-time "$OPT_TIMEOUT" -H "fly-prefer-region: $location" "$PROBE_URL" >"$TEMP_DIR/raw/$location" &
  CPID=$!
  wait "$CPID"
  exit_code=$?

  if [ "$exit_code" -eq 0 ]; then
    duration=$(echo "$(cat "$TEMP_DIR/raw/$location") * 1000" | bc | cut -d. -f1)
    echo "$duration" > "$TEMP_DIR/res/$location"
  else
    echo "ERROR" > "$TEMP_DIR/res/$location"
  fi
}

# Check if a location is a gateway
is_gateway() {
  local location="$1"
  for gateway in "${GATEWAY_REGIONS[@]}"; do
    if [ "$gateway" = "$location" ]; then
      echo "✓"
      return
    fi
  done
  echo " "
}

# Main script
parse_args "$@"
resolve_modes
if [ -n "$OPT_HELP" ]; then
  usage
  exit 0
fi
if [ -n "$OPT_VERSION" ]; then
  printf '%s\n' "$VERSION"
  exit 0
fi
if [ -n "$USAGE_ERR" ]; then
  die 2 "$USAGE_REASON" "$USAGE_ERR" "See all options" "$PROG --help"
fi
trap cleanup EXIT
trap 'stop_spinner; errf "Canceled.\nNothing was changed.\n"; exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 0' PIPE
make_temp

echo "Turso Latency Checker"
echo "====================="
echo "Measuring latency to all Turso locations..."
echo

# Start the latency tests in the background
for location in "${LOCATIONS[@]}"; do
  measure_latency "$location" &
  PIDS+=($!)
done

# Show a spinner animation as progress indicator
echo -n "Running tests: "
spinner=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
total=${#LOCATIONS[@]}
i=0
while true; do
  completed=$(ls "$TEMP_DIR/res" | wc -l)
  echo -ne "\rRunning tests: ${spinner[$i]} "
  
  if [ "$completed" -eq "$total" ]; then
    echo -e "\rRunning tests: Complete!          "
    break
  fi
  
  i=$(( (i+1) % ${#spinner[@]} ))
  sleep 0.1
done

echo

# All tests are now complete - collect and sort the results
echo "RESULTS (sorted by latency)"
echo "--------------------------------------------------------------------------------"
printf "%-6s  %-36s  %11s  %s\n" "ID" "LOCATION" "LATENCY" "GATEWAY"
echo "--------------------------------------------------------------------------------"

# Get all locations with their latency (excluding errors)
successful_locations=()
for location in "${LOCATIONS[@]}"; do
  if [ -f "$TEMP_DIR/res/$location" ] && [ "$(cat "$TEMP_DIR/res/$location")" != "ERROR" ]; then
    successful_locations+=("$location $(cat "$TEMP_DIR/res/$location")")
  fi
done

# Sort by latency (second field)
sorted_locations=()
while IFS= read -r entry; do
  sorted_locations+=("$entry")
done < <(printf '%s\n' "${successful_locations[@]}" | sort -n -k2)

# Get the fastest location
fastest_location=$(echo "${sorted_locations[0]}" | awk '{print $1}')
fastest_latency=$(echo "${sorted_locations[0]}" | awk '{print $2}')

# Print sorted results
for entry in "${sorted_locations[@]}"; do
  location=$(echo "$entry" | awk '{print $1}')
  latency=$(echo "$entry" | awk '{print $2}')
  gateway_mark=$(is_gateway "$location")
  
  # Make sure location name is not too long
  location_name=$(get_location_name "$location")
  if [ ${#location_name} -gt 36 ]; then
    location_name="${location_name:0:33}..."
  fi
  
  # Add special handling for cities with non-ASCII characters and highlight fastest
  if [ "$location" = "$fastest_location" ]; then
    case "$location" in
      "gru"|"bog"|"qro")
        printf "${BOLD}%-6s  %-36s   ${BOLD}%11s${RESET}${BOLD}  %s${RESET}\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
      *)
        printf "${BOLD}%-6s  %-36s  ${BOLD}%11s${RESET}${BOLD}  %s${RESET}\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
    esac
  else
    case "$location" in
      "gru"|"bog"|"qro")
        printf "%-6s  %-36s   %11s  %s\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
      *)
        printf "%-6s  %-36s  %11s  %s\n" "$location" "$location_name" "${latency}ms" "$gateway_mark"
        ;;
    esac
  fi
done

# List failed locations
failed_locations=()
for location in "${LOCATIONS[@]}"; do
  if [ -f "$TEMP_DIR/res/$location" ] && [ "$(cat "$TEMP_DIR/res/$location")" = "ERROR" ]; then
    failed_locations+=("$location")
  fi
done

if [ ${#failed_locations[@]} -gt 0 ]; then
  echo
  echo "Failed to connect to these regions:"
  for location in "${failed_locations[@]}"; do
    echo "- $location ($(get_location_name "$location"))"
  done
fi

# Show fastest region
if [ ${#sorted_locations[@]} -gt 0 ]; then
  fastest_entry="${sorted_locations[0]}"
  fastest_location=$(echo "$fastest_entry" | awk '{print $1}')
  fastest_latency=$(echo "$fastest_entry" | awk '{print $2}')
  
  # Check if it's a gateway
  gateway_info=""
  if [ "$(is_gateway "$fastest_location")" = "✓" ]; then
    gateway_info=" (Gateway Region)"
  fi
  
  echo
  echo -e "Fastest region: ${BOLD}$fastest_location ($(get_location_name "$fastest_location")) - ${BOLD}${fastest_latency}ms${RESET}${BOLD}${gateway_info}${RESET}"
else
  echo
  echo "No successful connections to any region."
fi

echo

exit 0
