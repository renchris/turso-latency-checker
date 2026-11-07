#!/usr/bin/env bash

# Turso Latency Checker (Simple Version)
# A simple script to measure latency to all Turso regions

# ---- cli helpers (inline: single-file distribution, see README direct download) ----
PROG=turso-latency-checker
VERSION=1.1.0
PROBE_HOST=region.turso.io:8080
PROBE_URL="http://$PROBE_HOST/"

# One record per option, in long-name order: long|short|hint|default|repeat|summary
OPTS="debug|d|||last_wins|Show each probe's raw result on stderr
help|h|||last_wins|Show this help
no-color||||last_wins|Disable color
non-interactive||||last_wins|Never animate progress (the CLI never prompts)
timeout||<DURATION>|3s|last_wins|Time limit for each probe, such as 5s (default: 3s)
version|v|||last_wins|Print the version"

OPT_DEBUG=
OPT_HELP=
OPT_VERSION=
OPT_NO_COLOR=
OPT_NON_INTERACTIVE=
OPT_TIMEOUT=
USAGE_REASON=
USAGE_ERR=
USAGE_ISSUES=()
DIE_ROWS=()
ERR_DIRTY=
TEMP_DIR=
PIDS=()

opt_default() {
  local long default
  while IFS='|' read -r long _ _ default _ _; do
    if [ "$long" = "$1" ]; then
      printf '%s' "$default"
      return
    fi
  done <<<"$OPTS"
}

# usage_issue <token> <reason> <row message> <headline when it is the only issue>
usage_issue() {
  if [ ${#USAGE_ISSUES[@]} -eq 0 ]; then
    USAGE_REASON=$2
    USAGE_ERR=$4
  fi
  USAGE_ISSUES+=("$1|$2|$3")
}

unknown_option() {
  usage_issue "$1" unknown_option "Unknown option." "Unknown option $1 for $PROG."
}

unknown_command() {
  usage_issue "$1" unknown_command "Unknown command." "Unknown command $1 for $PROG."
}

# bool_arg <the argument as typed> <--name> <variable>: bare or =true is true, =false
# means no override, anything else is a usage error.
bool_arg() {
  case "$1" in
    "$2" | "$2=true") printf -v "$3" '%s' true ;;
    "$2=false") printf -v "$3" '%s' false ;;
    *) usage_issue "$1" invalid_arguments "Use $2=true or $2=false." "Can't use $1. Use $2=true or $2=false." ;;
  esac
}

# Accepts 5 | 5s | 2.5s | 500ms, positive only; normalizes to seconds for curl.
set_timeout() {
  local value=$1 number=$1 re='^([0-9]+(\.[0-9]+)?|\.[0-9]+)(ms|s)?$' advice='Use a positive duration, such as 5s.'
  if [ -z "$value" ]; then
    usage_issue --timeout invalid_arguments "$advice" "Can't use --timeout without a value. $advice"
    return
  fi
  if ! [[ $value =~ $re ]]; then
    usage_issue "--timeout $value" invalid_arguments "$advice" "Can't use --timeout $value. $advice"
    return
  fi
  case "$value" in
    *ms) number=$(LC_ALL=C awk -v n="${value%ms}" 'BEGIN { printf "%g", n / 1000 }') ;;
    *s) number=${value%s} ;;
  esac
  case "$number" in
    *[1-9]*) OPT_TIMEOUT=$number ;;
    *) usage_issue "--timeout $value" invalid_arguments "$advice" "Can't use --timeout $value. $advice" ;;
  esac
}

# Collects every usage problem and keeps scanning, so -h anywhere still wins.
parse_args() {
  local arg first=1 positional_only=
  set_timeout "$(opt_default timeout)"
  while [ $# -gt 0 ]; do
    arg=$1
    shift
    if [ -n "$positional_only" ]; then
      unknown_command "$arg"
      continue
    fi
    case "$arg" in
      help)
        if [ -n "$first" ]; then OPT_HELP=1; else unknown_command "$arg"; fi
        ;;
      -d | --debug | --debug=*)
        if [ "$arg" = -d ]; then arg=--debug; fi
        bool_arg "$arg" --debug OPT_DEBUG
        ;;
      -h | --help) OPT_HELP=1 ;;
      -v | --version) OPT_VERSION=1 ;;
      --no-color | --no-color=*) bool_arg "$arg" --no-color OPT_NO_COLOR ;;
      --non-interactive | --non-interactive=*) bool_arg "$arg" --non-interactive OPT_NON_INTERACTIVE ;;
      --timeout)
        if [ $# -eq 0 ]; then
          set_timeout ''
        else
          case "$1" in
            -*) set_timeout '' ;;
            *)
              set_timeout "$1"
              shift
              ;;
          esac
        fi
        ;;
      --timeout=*) set_timeout "${arg#--timeout=}" ;;
      --) positional_only=1 ;;
      -*) unknown_option "$arg" ;;
      *) unknown_command "$arg" ;;
    esac
    first=
  done
  case "${TURSO_LATENCY_ACCESSIBLE:-}" in
    '' | 1) ;;
    *)
      usage_issue "TURSO_LATENCY_ACCESSIBLE=$TURSO_LATENCY_ACCESSIBLE" invalid_arguments \
        "Use 1, or leave it empty." "Can't use TURSO_LATENCY_ACCESSIBLE=$TURSO_LATENCY_ACCESSIBLE. Use 1, or leave it empty."
      ;;
  esac
  if [ ${#USAGE_ISSUES[@]} -gt 1 ]; then
    USAGE_REASON=invalid_arguments
    USAGE_ERR="Can't measure latency. ${#USAGE_ISSUES[@]} inputs are invalid."
  fi
}

# The issue rows for a multi-problem usage error: at most 5, then a count.
usage_rows() {
  local issue token message shown=0 total=${#USAGE_ISSUES[@]}
  DIE_ROWS=()
  [ "$total" -gt 1 ] || return 0
  for issue in "${USAGE_ISSUES[@]}"; do
    if [ "$shown" -eq 5 ]; then
      DIE_ROWS+=("and $((total - shown)) more")
      return 0
    fi
    token=${issue%|*|*}
    message=${issue##*|}
    DIE_ROWS+=("$token: $message")
    shown=$((shown + 1))
  done
}

# plural <n> <one> <many>: "1 region", "2 regions".
plural() {
  if [ "$1" -eq 1 ]; then printf '%s %s' "$1" "$2"; else printf '%s %s' "$1" "$3"; fi
}

# Precedence: --no-color > non-empty NO_COLOR > FORCE_COLOR (0=off, other=on) > a terminal.
color_for() {
  [ "$OPT_NO_COLOR" = true ] && return 1
  [ -n "${NO_COLOR:-}" ] && return 1
  if [ -n "${FORCE_COLOR:-}" ]; then
    [ "$FORCE_COLOR" != 0 ]
    return
  fi
  [ -t "$1" ] && [ "${TERM:-}" != dumb ]
}

resolve_modes() {
  local size=
  TTY_OUT=
  TTY_ERR=
  RICH_OUT=
  RICH_ERR=
  INTERACTIVE=
  ANIMATE=
  ACCESSIBLE=
  BOLD=
  RESET=
  HELP_HEADING=
  HELP_COMMAND=
  HELP_FAINT=
  E_RED=
  E_CYAN=
  E_RESET=
  COLS_OUT=80
  if [ -t 1 ]; then
    TTY_OUT=1
    # stty reads the terminal through fd 3: inside $(...), <&1 would be the substitution's pipe.
    { size=$(stty size <&3 2>/dev/null); } 3>&1
    size=${size#* }
    case "$size" in
      '' | 0 | *[!0-9]*) ;;
      *) COLS_OUT=$size ;;
    esac
  fi
  if [ -t 2 ]; then TTY_ERR=1; fi
  if [ -n "$TTY_OUT" ] && [ "${TERM:-}" != dumb ]; then RICH_OUT=1; fi
  if [ -n "$TTY_ERR" ] && [ "${TERM:-}" != dumb ] && [ -z "${TURSO_LATENCY_ACCESSIBLE:-}" ]; then RICH_ERR=1; fi
  if [ -n "${TURSO_LATENCY_ACCESSIBLE:-}" ]; then ACCESSIBLE=1; fi
  # --non-interactive=false restores animation for a detected agent, and for nothing else.
  if [ -t 0 ] && [ -t 2 ] && [ -z "${CI:-}" ] && [ "$OPT_NON_INTERACTIVE" != true ] &&
    { [ -z "${CLAUDECODE:-}" ] || [ "$OPT_NON_INTERACTIVE" = false ]; }; then
    INTERACTIVE=1
  fi
  # Not gated on color: turning color off removes only color.
  if [ -n "$RICH_ERR" ] && [ -n "$INTERACTIVE" ]; then ANIMATE=1; fi
  if [ -n "$RICH_OUT" ] && color_for 1; then
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
    HELP_HEADING=$'\033[1;34m'
    HELP_COMMAND=$'\033[36m'
    HELP_FAINT=$'\033[2m'
  fi
  # Forced color on a plain stderr tints only the Error:/Warning: prefix.
  if color_for 2; then
    E_RED=$'\033[31m'
    E_RESET=$'\033[0m'
    if [ -n "$RICH_ERR" ]; then E_CYAN=$'\033[36m'; fi
  fi
  GLYPH_ERR='Error:'
  GLYPH_OK=
  GUTTER=
  ELLIPSIS='...'
  if [ -n "$RICH_ERR" ]; then
    GLYPH_ERR='✗'
    GLYPH_OK='✓ '
    GUTTER='  '
    ELLIPSIS='…'
  fi
}

# A closed pipe ends quietly.
outf() {
  local fmt=$1
  shift
  # shellcheck disable=SC2059
  printf "$fmt" "$@" 2>/dev/null || exit 0
}

# Debug lines are always allowed on stderr, and hold no remote text.
dbg() {
  printf 'debug: %s\n' "$1" >&2
  ERR_DIRTY=1
}

errf() {
  local fmt=$1
  shift
  # shellcheck disable=SC2059
  printf "$fmt" "$@" >&2
  ERR_DIRTY=1
}

SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
SPINNER_DRAWN=
SPINNER_INDEX=0
SPINNER_LABEL=Measuring

# draw_spinner <finished> <total>: one frame on stderr, only when animating.
draw_spinner() {
  [ -n "$ANIMATE" ] || return 0
  printf '\r%s %s%s %d of %d ' "${SPINNER_FRAMES[$SPINNER_INDEX]}" "$SPINNER_LABEL" "$ELLIPSIS" "$1" "$2" >&2
  SPINNER_INDEX=$(((SPINNER_INDEX + 1) % ${#SPINNER_FRAMES[@]}))
  SPINNER_DRAWN=1
}

stop_spinner() {
  if [ -n "$SPINNER_DRAWN" ]; then
    printf '\r\033[K' >&2
    SPINNER_DRAWN=
  fi
}

# row <label> <value>: the one layout for a labeled detail row on stderr.
row() {
  errf '  %-16s%s\n' "$1" "$2"
}

# die <exit> <reason> <headline> [<recovery-label> <recovery-cmd>]
die() {
  local code=$1 headline=$3 label=${4:-} cmd=${5:-} row
  stop_spinner
  if [ -n "$ERR_DIRTY" ]; then errf '\n'; fi
  errf '%s%s%s %s\n' "$E_RED" "$GLYPH_ERR" "$E_RESET" "$headline"
  if [ ${#DIE_ROWS[@]} -gt 0 ]; then
    for row in "${DIE_ROWS[@]}"; do
      errf '  %s\n' "$row"
    done
  fi
  if [ -n "$label" ]; then
    errf '\n%s:\n    %s%s%s\n' "$label" "$E_CYAN" "$cmd" "${E_CYAN:+$E_RESET}"
  fi
  exit "$code"
}

cleanup() {
  local jobs_left
  trap - EXIT INT TERM HUP PIPE
  # Every started job, including one a signal caught before PIDS recorded it.
  jobs_left=$(jobs -p)
  if [ -n "$jobs_left" ]; then
    kill $jobs_left 2>/dev/null
    wait 2>/dev/null
  fi
  stop_spinner
  if [ -n "$TEMP_DIR" ]; then rm -rf "${TEMP_DIR:?}"; fi
}

# All missing tools in one pass; install steps vary by OS, so no recovery command.
check_dependencies() {
  local tool missing=() list
  for tool in curl awk mktemp; do
    if ! command -v "$tool" >/dev/null 2>&1; then missing+=("$tool"); fi
  done
  [ ${#missing[@]} -gt 0 ] || return 0
  list=${missing[0]}
  case ${#missing[@]} in
    2) list="${missing[0]} and ${missing[1]}" ;;
    3) list="${missing[0]}, ${missing[1]}, and ${missing[2]}" ;;
  esac
  if [ ${#missing[@]} -eq 1 ]; then
    die 1 missing_dependency "Can't measure latency without $list. Install it and rerun $PROG."
  fi
  die 1 missing_dependency "Can't measure latency without $list. Install them and rerun $PROG."
}

make_temp() {
  TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/turso-latency.XXXXXX" 2>/dev/null) ||
    die 1 temp_dir_unavailable "Couldn't create a temp directory in ${TMPDIR:-/tmp}."
  mkdir "$TEMP_DIR/res" "$TEMP_DIR/raw" "$TEMP_DIR/err"
}

# The directory is mktemp-private, so a fixed dot-name is safe.
atomic_write() {
  local tmp="${1%/*}/.${1##*/}.tmp"
  printf '%s\n' "$2" >"$tmp" && mv -f "$tmp" "$1"
}

# Code points, independent of the locale; every region name is width-1 per point.
display_width() {
  local LC_ALL=C bare
  bare=${1//[$'\200'-$'\277']/}
  printf '%s' "${#bare}"
}

pad_to() {
  printf '%s%*s' "$1" $(($2 - $(display_width "$1"))) ''
}

# shorten <s> <cols>: cuts by display width, a whole UTF-8 sequence at a time.
shorten() {
  if [ "$(display_width "$1")" -le "$2" ]; then
    printf '%s' "$1"
    return
  fi
  printf '%s\n' "$1" | LC_ALL=C awk -v keep="$(($2 - 1))" '{
    n = 0
    out = ""
    for (i = 1; i <= length($0); i++) {
      c = substr($0, i, 1)
      if (c < "\200" || c >= "\300") {
        if (n == keep) break
        n++
      }
      out = out c
    }
    printf "%s…", out
  }'
}

# The longest a run can take, in whole seconds: 2 attempts, the backoff and 2 seconds of slack.
probe_deadline_seconds() {
  LC_ALL=C awk -v t="$OPT_TIMEOUT" 'BEGIN { d = 2 * t + 2.5; printf "%d", (d == int(d)) ? d : int(d) + 1 }'
}

# cause_for <curl exit> <http code> <attempts> <stderr file>: sets CAUSE_TEXT, the one
# place a failure's words come from. A missing exit means the probe left no result.
cause_for() {
  local retried='' detail
  if [ "${3:-1}" -gt 1 ]; then retried='; retried once'; fi
  case "$1" in
    '') CAUSE_TEXT="no result within $(probe_deadline_seconds)s" ;;
    28) CAUSE_TEXT="timed out after ${OPT_TIMEOUT}s$retried" ;;
    6) CAUSE_TEXT="DNS lookup failed$retried" ;;
    7) CAUSE_TEXT="connection refused$retried" ;;
    *)
      detail=$(sed -n '1s/^curl: ([0-9]*) //p' "$4")
      CAUSE_TEXT="curl exit $1${detail:+: $detail}$retried"
      ;;
  esac
}
# ---- end cli helpers ----

print_options() {
  local long short hint summary flag name
  while IFS='|' read -r long short hint _ _ summary; do
    flag='    '
    if [ -n "$short" ]; then flag="-$short, "; fi
    name="--$long"
    if [ -n "$hint" ]; then name="$name $hint"; fi
    printf '  %s%-22s%s\n' "$flag" "$name" "$summary"
  done <<<"$OPTS"
}

# Plain help goes through untouched; a rich terminal gets headings, option names,
# example commands and the summary styled, and everything else in normal foreground.
style_help() {
  local line section=
  if [ -z "$RESET" ]; then
    cat
    return
  fi
  while IFS= read -r line; do
    case "$line" in
      Usage:*) section=summary ;;
      Options: | Examples: | Notes:)
        section=$line
        printf '%s%s%s\n' "$HELP_HEADING" "$line" "$RESET"
        continue
        ;;
      'Learn more: '*)
        printf '%sLearn more:%s %s\n' "$HELP_HEADING" "$RESET" "${line#Learn more: }"
        continue
        ;;
      '') ;;
      *)
        case "$section" in
          summary)
            printf '%s%s%s\n' "$HELP_FAINT" "$line" "$RESET"
            section=
            continue
            ;;
          Options:)
            printf '%s%s%s%s\n' "$BOLD" "${line:0:28}" "$RESET" "${line:28}"
            continue
            ;;
          Examples:)
            case "$line" in
              '    '*)
                printf '    %s%s%s\n' "$HELP_COMMAND" "${line#    }" "$RESET"
                continue
                ;;
            esac
            ;;
        esac
        ;;
    esac
    printf '%s\n' "$line"
  done
}

usage() {
  {
  cat <<'USAGE'
Usage: turso-latency-checker [options]
Measure latency to every Turso region and show the fastest

Options:
USAGE
  print_options
  cat <<'USAGE'

Examples:
  Measure every region
    turso-latency-checker

  Give slow links more time
    turso-latency-checker --timeout 10s

Notes:
  Each region gets a plain-HTTP GET to http://region.turso.io:8080/ with a
  fly-prefer-region header. All regions run in parallel, and a failed probe
  is retried once.
  Results go to stdout; progress goes to stderr.
  Honors NO_COLOR, FORCE_COLOR, CI, CLAUDECODE, and TURSO_LATENCY_ACCESSIBLE=1.
  An empty variable counts as unset, and options win over variables. Nothing
  is saved between runs.
  Exits 0 after a finished run, even when regions failed; 1 when it can't
  start; 2 on a usage error.

Learn more: https://github.com/renchris/turso-latency-checker#readme
USAGE
  } | style_help
}

# Every Turso region
LOCATIONS=("ams" "arn" "atl" "bog" "bom" "bos" "cdg" "den" "dfw" "ewr" "eze" "fra" "gdl" "gig" "gru" "hkg" "iad" "jnb" "lax" "lhr" "mad" "mia" "nrt" "ord" "otp" "phx" "qro" "scl" "sea" "sin" "sjc" "syd" "waw" "yul" "yyz")

# Gateway regions
GATEWAY_REGIONS=("ams" "cdg" "dfw" "fra" "hkg" "iad" "lax" "lhr" "nrt" "ord" "scl" "sea" "sin" "sjc" "syd" "yyz")

# The city name for each region, for readability
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
    *) printf '%s\n' "$1" ;;
  esac
}

# Measures one region. It runs as a background job and owns its curl, so
# cancellation stops the probe too. A failed probe is recorded, never a latency.
# A transient failure is retried once, and only the last attempt's timing counts.
measure_latency() {
  local location=$1 rc ms attempt=1 re='^[0-9]+$' total code
  trap 'kill $(jobs -p) 2>/dev/null; exit 143' TERM

  while :; do
  curl -sS -o /dev/null -w '%{time_total} %{http_code}' --max-time "$OPT_TIMEOUT" -H "fly-prefer-region: $location" "$PROBE_URL" \
    >"$TEMP_DIR/raw/$location" 2>"$TEMP_DIR/err/$location" &
  wait $!
  rc=$?
  atomic_write "$TEMP_DIR/raw/$location.exit" "$rc"
  if [ "$attempt" -eq 1 ]; then
    case "$rc" in
      6 | 7 | 28 | 35 | 52 | 56)
        : >"$TEMP_DIR/.retrying"
        attempt=2
        sleep 0.5
        continue
        ;;
    esac
  fi
  break
  done

  read -r total code <"$TEMP_DIR/raw/$location"
  ms=$(LC_ALL=C awk -v t="$total" 'BEGIN { if (t !~ /^[0-9]*\.?[0-9]+$/) exit 1; printf "%d", t * 1000 }')
  if [ "$rc" -eq 0 ] && [[ $ms =~ $re ]]; then
    atomic_write "$TEMP_DIR/res/$location" "$ms"
  else
    atomic_write "$TEMP_DIR/res/$location" "ERROR $rc $attempt ${code:-000}"
  fi
}

start_probes() {
  local location
  for location in "${LOCATIONS[@]}"; do
    measure_latency "$location" &
    PIDS+=($!)
  done
}

# Waits for every probe, up to the deadline, then stops whatever is left.
wait_for_probes() {
  local deadline pid alive location finished retry_noted='' still_noted='' usual_seconds still_after
  deadline=$((SECONDS + $(probe_deadline_seconds)))
  usual_seconds=$(LC_ALL=C awk -v t="$OPT_TIMEOUT" 'BEGIN { c = (t == int(t)) ? t : int(t) + 1; printf "%d", c + 1 }')
  still_after=$((SECONDS + usual_seconds))
  while :; do
    alive=0
    for pid in "${PIDS[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then alive=$((alive + 1)); fi
    done
    finished=0
    for location in "${LOCATIONS[@]}"; do
      if [ -f "$TEMP_DIR/res/$location" ]; then finished=$((finished + 1)); fi
    done
    if [ -z "$retry_noted" ] && [ -e "$TEMP_DIR/.retrying" ]; then
      retry_noted=1
      if [ -n "$ANIMATE" ]; then
        SPINNER_LABEL='Retrying automatically'
      else
        errf '%sRetrying automatically%s\n' "$GUTTER" "$ELLIPSIS"
      fi
    fi
    if [ -z "$still_noted" ] && [ "$alive" -gt 0 ] && [ "$SECONDS" -gt "$still_after" ]; then
      still_noted=1
      stop_spinner
      errf '%sStill measuring %s. Most runs finish within %s.\n' "$GUTTER" \
        "$(plural $((${#LOCATIONS[@]} - finished)) region regions)" "$(plural "$usual_seconds" second seconds)"
    fi
    draw_spinner "$finished" "${#LOCATIONS[@]}"
    if [ "$alive" -eq 0 ]; then break; fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      kill "${PIDS[@]}" 2>/dev/null
      break
    fi
    sleep 0.1
  done
  wait "${PIDS[@]}" 2>/dev/null
  PIDS=()
  stop_spinner
}

# One line per region: the raw facts of its last attempt, or none for a region with no result.
print_debug() {
  local location rc total code
  [ "$OPT_DEBUG" = true ] || return 0
  for location in "${LOCATIONS[@]}"; do
    if [ ! -f "$TEMP_DIR/res/$location" ]; then
      dbg "$location curl_exit=none http=none time_total=none"
      continue
    fi
    rc=$(cat "$TEMP_DIR/raw/$location.exit")
    read -r total code <"$TEMP_DIR/raw/$location"
    dbg "$location curl_exit=$rc http=${code:-000} time_total=${total:-0}"
  done
}

# A missing file, an empty value or an ERROR value all count as failed.
classify_results() {
  local location value
  OK_ROWS=()
  FAILED=()
  for location in "${LOCATIONS[@]}"; do
    value=
    if [ -f "$TEMP_DIR/res/$location" ]; then read -r value <"$TEMP_DIR/res/$location"; fi
    case "$value" in
      '' | *[!0-9]*) FAILED+=("$location") ;;
      *) OK_ROWS+=("$location $value") ;;
    esac
  done
  SORTED_ROWS=()
  if [ ${#OK_ROWS[@]} -gt 0 ]; then
    while IFS= read -r value; do
      SORTED_ROWS+=("$value")
    done < <(printf '%s\n' "${OK_ROWS[@]}" | sort -n -k2)
  fi
}

is_gateway() {
  local gateway
  for gateway in "${GATEWAY_REGIONS[@]}"; do
    if [ "$gateway" = "$1" ]; then return 0; fi
  done
  return 1
}

# The Location column on a terminal: 26 is ID 6, Latency 7, Gateway 7 and three gaps.
terminal_location_width() {
  local width=$((COLS_OUT - 26))
  if [ "$width" -gt 36 ]; then width=36; fi
  printf '%s' "$width"
}

print_rule() {
  local width=$(($(terminal_location_width) + 26)) rule
  rule=$(printf '%*s' "$width" '')
  outf '%s\n' "${rule// /-}"
}

print_header() {
  local width
  if [ -z "$TTY_OUT" ]; then
    outf "%-6s  %-36s  %11s  %s\n" "ID" "LOCATION" "LATENCY" "GATEWAY"
    return
  fi
  width=$(terminal_location_width)
  # Below 8 columns for Location each region prints as a record, with no header.
  if [ "$width" -lt 8 ]; then return; fi
  print_rule
  outf "%-6s  %-${width}s  %7s  %s\n" "ID" "LOCATION" "LATENCY" "GATEWAY"
  print_rule
}

# print_row <location> <latency> <style-on> <style-off>: styles only the ID cell.
print_row() {
  local name gateway=' ' width
  name=$(get_location_name "$1")
  if [ -n "$ACCESSIBLE" ]; then gateway=no; fi
  if is_gateway "$1"; then
    gateway='✓'
    if [ -n "$ACCESSIBLE" ]; then gateway=yes; fi
  fi
  if [ -z "$TTY_OUT" ]; then
    outf '%s%-6s%s  %s  %11s  %s\n' "$3" "$1" "$4" "$(pad_to "$name" 36)" "$2ms" "$gateway"
    return
  fi
  width=$(terminal_location_width)
  if [ "$width" -lt 8 ]; then
    if is_gateway "$1"; then gateway='  gateway'; else gateway=''; fi
    outf '%s%s%s  %s%s\n' "$3" "$1" "$4" "$2ms" "$gateway"
    outf '  %s\n' "$(shorten "$name" $((COLS_OUT - 2)))"
    return
  fi
  outf '%s%-6s%s  %s  %7s  %s\n' "$3" "$1" "$4" "$(pad_to "$(shorten "$name" "$width")" "$width")" "$2ms" "$gateway"
}

main() {
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
  usage_rows
  die 2 "$USAGE_REASON" "$USAGE_ERR" "See all options" "$PROG --help"
fi
check_dependencies
trap cleanup EXIT
trap 'stop_spinner; errf "Canceled.\nNothing was changed.\n"; exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 0' PIPE
make_temp

errf '%sMeasuring latency to %d Turso regions via %s%s\n' "$GUTTER" "${#LOCATIONS[@]}" "$PROBE_HOST" "$ELLIPSIS"

start_probes
wait_for_probes
print_debug
classify_results
if [ ${#FAILED[@]} -eq 0 ]; then
  errf '%sMeasured %s.\n' "$GLYPH_OK" "$(plural "${#LOCATIONS[@]}" region regions)"
else
  errf '%sMeasured %d of %d regions. %d failed.\n' "$GUTTER" "${#OK_ROWS[@]}" "${#LOCATIONS[@]}" "${#FAILED[@]}"
fi

print_header

# Get the fastest region
fastest_location=
fastest_latency=
if [ ${#SORTED_ROWS[@]} -gt 0 ]; then
  fastest_location=${SORTED_ROWS[0]% *}
  fastest_latency=${SORTED_ROWS[0]#* }
fi

for entry in ${SORTED_ROWS[@]+"${SORTED_ROWS[@]}"}; do
  if [ "${entry% *}" = "$fastest_location" ]; then
    print_row "${entry% *}" "${entry#* }" "$BOLD" "$RESET"
  else
    print_row "${entry% *}" "${entry#* }" '' ''
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  outf '\n'
  outf "Couldn't reach %s via %s\n" "$(plural "${#FAILED[@]}" region regions)" "$PROBE_HOST"
  for location in "${FAILED[@]}"; do
    rc=
    attempts=
    code=
    if [ -f "$TEMP_DIR/res/$location" ]; then read -r _ rc attempts code <"$TEMP_DIR/res/$location"; fi
    cause_for "$rc" "$code" "$attempts" "$TEMP_DIR/err/$location"
    outf '%s\n' "- $location ($(get_location_name "$location")): $CAUSE_TEXT"
  done
fi

outf '\n'
if [ -n "$fastest_location" ]; then
  gateway_info=''
  if is_gateway "$fastest_location"; then gateway_info=' (Gateway Region)'; fi
  outf 'Fastest region: %s%s%s (%s) - %sms%s\n' "$BOLD" "$fastest_location" "$RESET" "$(get_location_name "$fastest_location")" "$fastest_latency" "$gateway_info"
else
  outf 'No successful connections to any region.\n'
fi

exit 0
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
