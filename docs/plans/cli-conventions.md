# Remediation plan: turso-latency-checker

Plan only. Nothing in the repo was edited and the CLI was not executed. Everything below comes from static reading (`cat -n`, `grep`, `git diff`), from `shellcheck` on the script, and from `/tmp/cli-bp/checklist.md` and `/tmp/cli-bp/guidelines.md`. The Round 2 re-check also ran PTY probes with its own child scripts, never this CLI (section 7).

## Phase 0: Agent team orchestration

**Execution locus per wave.** S is the default for every implementation wave. Each S session is fired with `handoff-fire.sh --prompt-file <brief> --worktree <br> --notify-back <lead-uuid> --goal '…'`, with one end state per fire.

| Session | Locus | Scope (unit) | `--goal` |
|---|---|---|---|
| S1 | S | U2: Wave A + B tests, fixtures, helpers | `test/turso-latency-checker.bats holds every A-T*/B*-T* test from the plan and each fails against HEAD's script, except the contract guard B3-T2, which must pass both before and after the fix — proven by printing 'TLC_BASH=/bin/bash bats test/' TAP output; do not edit turso-latency-checker.sh, README.md or package.json, and do not let any test reach the network` |
| S2 | S | U1: Wave A + B1–B7 in `turso-latency-checker.sh` (Round 2: A, A2, B1–B16; B13b waits for D9) | `all A/B tests pass on bash 3.2 and 5.3 with 0 shellcheck warnings — proven by printing the four gate commands' output; do not touch README.md, package.json or ~/bin, and do not run the CLI without the curl stub` |
| S3 | S | U5: C1–C4 tests in `test/contract.bats` (after D1–D3 and D6; Round 2: was U2) | `C*-T* tests exist in test/contract.bats and fail against the phase-1 script, except the guard C2-T3 (and C2-T2 if D2 = 0), which already pass — proven by printing the bats TAP output with its 1..N plan line; do not edit the script, test/helpers.bash, test/fixtures/ or test/turso-latency-checker.bats` |
| S4 | S | U4: C1→C2→C3→C4 (Round 2: was U1; serial successor owner of the script, see D8) | `all A/B/C tests pass on both bashes with 0 shellcheck warnings — proven by printing the four gate commands' output, each bats run showing its 1..N plan line; do not touch README.md, package.json or any test file` |
| S5 | S | U3: README.md, package.json, CHANGELOG.md (after D4) | `package.json version equals the script VERSION and A-T3 runs unskipped and passes — proven by printing 'jq .version package.json' and the bats output; do not publish to npm` |

There are no T or L waves. Every unit writes code, and the code must not land in the lead's window.

**Roster.** S1 and S3 are the test author (U2). S2 and S4 are the script implementer (U1). S5 is the docs/metadata author (U3). Background subagents are research-only and make no code changes. **Round 2:** S1 is U2 (phase-1 tests), S2 is U1 (phase-1 script), S3 is U5 (phase-2 tests, new file `test/contract.bats`), S4 is U4 (phase-2 script), S5 is U3. See section 6 for why U1 and U4 share the one script file.

**Dependency graph and spawn order.** S1 → S2 → (operator answers D1–D3, and D6 for C4) → S3 → S4. S5 starts after D4. It can land its 1.2.0 part after S2 and its 2.0.0 part after S4. **Round 2 re-check:** B13's classification half (B13b, with B13-T1 and B13-T2) is the one phase-1 item gated on D9. If D9 is open when S1 fires, S1 and S2 land everything else and stop, a follow-up fire lands B13b in the same red-first order, and 1.2.0 waits for it. If D9 is already answered, they land it in order.

**Worktree.** All five sessions use one worktree, `/Users/chrisren/Development/.worktrees/tlc-cli-bp` on branch `cli-bp/turso-latency-checker`, created from `main`. They use it one after another, never at the same time, so file ownership never overlaps in time. S5 first rebases onto the operator's D4 commit.

**Lead budget and succession.** The lead reads this plan, fires the sessions, and reads 5 notify-backs. It never reads diffs inline; it only checks the gate output each session prints. Succession point: after S2's PR merges, while D1–D3 are pending. A fresh lead can resume from this file and the branch log alone.

## 1. Header

| Item | Value |
|---|---|
| Repo | `/Users/chrisren/Development/turso-latency-checker` (branch `main`, origin `github.com/renchris/turso-latency-checker`, HEAD `61cf16b`) |
| CLIs covered | `turso-latency-checker`: the npm bin `package.json:6-8` -> `./turso-latency-checker.sh` (219 lines, one command, no options today). `/Users/chrisren/bin/turso-latency-checker` is a byte-identical deployed copy (`cmp` printed SAME), not a separate CLI. It is outside the repo and is refreshed only by the operator (D5). |
| Repo rules | None. The repo has no `CLAUDE.md`, `.claude/`, `AGENTS.md`, CI, hooks or `test/` (measured: `ls -a`). The operator's global landing rules apply unchanged. |
| Dirty files (DO NOT TOUCH) | `git status --porcelain` shows ` M README.md` and ` M package.json` (measured). HEAD's `package.json` is a **0-byte file** (blob `e69de29`). The 31-line manifest that matches published npm 1.1.0 exists only in the uncommitted working copy. The README's npm-install section is also uncommitted. Both files have mtime 2025-04-20. Every README/package.json change in this plan is therefore owned by unit U3, which is **blocked on D4**. |
| Bash floor | `#!/bin/bash` on macOS is bash **3.2.57** (measured: `/bin/bash --version`). All new code must run on 3.2. Not allowed: `mapfile`/`readarray`, `declare -A`, `${x,,}`, `wait -n`, `;;&`, `local -n`. Put `[[ =~ ]]` regexes in a variable: `re='^[0-9]+$'; [[ $v =~ $re ]]`. |
| Distribution constraint | The script ships as **one file**. npm `files` lists only the script (working-copy `package.json:9-11`), and README.md:37 tells users to `curl -o` the raw script. Any helper must therefore be **inlined** in the script, not shipped as a sourced `lib/` file. |

### Gates (run from the implementation worktree root; all are offline)

```
bash -n turso-latency-checker.sh && /bin/bash -n turso-latency-checker.sh
shellcheck -S warning turso-latency-checker.sh test/fixtures/bin/curl && shellcheck -s bash -S warning test/helpers.bash
TLC_BASH=/bin/bash bats test/
TLC_BASH=/opt/homebrew/bin/bash bats test/
```

- Baseline (measured with `shellcheck -S warning -f gcc` on HEAD's script): 4 warnings. They are SC2034 at :55 (`CYAN` unused), SC2155 at :71 and :75 (`local x=$(...)`, which is the root of finding 1), and SC2207 at :140. The gate target is 0 warnings. The two `printf "$fmt"` helpers in Wave A carry a one-line `# shellcheck disable=SC2059`, and no other disables are allowed.
- bats is 1.13.0 (measured). It is the `cc-bats` wrapper, a QoS shim around real bats. Use `bats_require_minimum_version 1.5.0` and `run --separate-stderr`.
- Tests must never reach the network. `test/helpers.bash` puts `test/fixtures/bin` (stub `curl`) first on `PATH`. It also sets `http_proxy=https_proxy=HTTPS_PROXY=ALL_PROXY=http://127.0.0.1:9` so a stub miss fails fast, and every probing test asserts the stub log is non-empty.
- Do not use `npm test` as a gate. Today it is the npm placeholder that runs `exit 1`, and U3 rewires it only after D4.
- **Round 2: a refused bats run is not a pass.** `bats` on this machine resolves to `~/.claude/bin/bats` → `claude-infrastructure/bin/cc-bats` (measured: `type -a bats`, `ls -la`). Under load cc-bats refuses, prints a deferral notice with no TAP lines and exits 0 (`claude-infrastructure/docs/lessons/a-gate-refusal-is-not-a-gate-result.md`). Each bats gate therefore runs as `TLC_BASH=<bash> bats --tap test/ > "$TMPDIR/tap.txt"` and passes only when all three hold: line 1 is `1..N`; N equals `grep -c '^@test' test/*.bats` summed; and `grep -c '^ok '` equals N. A run without the plan line is a deferral: rerun it, never report it.

### Landing flow

1. Implementation happens in a separate worktree on a feature branch from `main` (e.g. `cli-bp/turso-latency-checker`), created per the operator's global rules. The main checkout's dirty README.md/package.json are never touched.
   - A fresh worktree from HEAD has the 0-byte `package.json` and the pre-npm README. That is expected. Do not "fix" it there; that is D4.
2. **Phase 1 (release 1.2.0, compatible):** U2 (tests) and U1 (script) land Wave A and Wave B. Use one commit per item (A, A2, B1 … B16; A2 and B8–B16 were added in Round 2), and every commit must pass all four gates. Write tests first, so they are red against HEAD and green after the fix.
3. **Phase 2 (release 2.0.0, contract):** after D1–D3 are answered, U1 and U2 land C1 → C2 → C3 in that order. (Round 2: U4 and U5 land C1 → C2 → C3 → C4; C4 also needs D6.) U3 lands docs/metadata in the same PR as the release it describes, after D4.
4. After merging, the operator alone does `npm publish` (an outbound action) and refreshes `~/bin/turso-latency-checker` (D5). Implementers do neither.

---

## 2. Wave A: one shared helper block (inline, top of `turso-latency-checker.sh`)

**Why a shared helper:** 13 of the 14 kept findings come from four missing central pieces. The exception is the npm-metadata finding (14).

| Missing piece | Findings it causes |
|---|---|
| No argv parser | 2 (help/version/unknown), 8 (`--no-color`), 10 (`--json`), 12 (`--timeout`) |
| No per-stream mode resolution | 3 (stdout noise), 7 (spinner), 8 (color), 9 (table), 10 (JSON) |
| No outcome/error/exit helper | 1 (fake successes), 4 (always exit 0), 10 (machine errors), 11 (error copy) |
| No lifecycle (temp, traps, atomic write) | 5 (unbounded wait), 6 (orphans and leaks), 1 (missing result file) |

These pieces are fixed once, in one block, and the command body then calls them (the guide's "enforce the rules in shared code").

**Location:** `turso-latency-checker.sh`, a new section right after the shebang and header comment. It replaces `:54-62`, the color constants and the temp dir. The block is delimited by `# ---- cli helpers (inline: single-file distribution, see README direct download) ----` and `# ---- end cli helpers ----`. It is about **120 LOC** (estimated by line-counting the API below). If the cross-repo audit later produces a canonical bash helper, copy its function names verbatim into this block. Still do not `source` it, because of the distribution constraint.

**API** (all globals UPPER_CASE, all bash-3.2 safe):

```bash
PROG=turso-latency-checker
VERSION=1.1.0                          # must equal package.json "version" (test A-T3)
PROBE_HOST=region.turso.io:8080; PROBE_URL="http://$PROBE_HOST/"

parse_args "$@"     # sets OPT_HELP OPT_VERSION OPT_NO_COLOR OPT_TIMEOUT(=3) [OPT_JSON in C3]
                    # records only the FIRST usage error in USAGE_REASON/USAGE_ERR and keeps
                    # scanning, so -h anywhere still wins (R083) and --json anywhere selects the
                    # error format (C3). Arms: help (argv[0] only) | -h | --help, -v | --version,
                    # --no-color, --timeout <DURATION> | --timeout=<DURATION>, -- (anything after
                    # it is an unknown_command), -* -> unknown_option, * -> unknown_command.
set_timeout <v>     # accepts 5 | 5s | 2.5s | 500ms; positive only; normalizes to seconds for curl;
                    # else usage error "Can't use --timeout <v>. Use a positive duration, such as 5s."
color_for <fd>      # R206 precedence: --no-color > non-empty NO_COLOR > FORCE_COLOR (0=off, other=on)
                    # > [ -t fd ] && TERM != dumb
resolve_modes       # once, after parse_args: TTY_OUT TTY_ERR; BOLD/RESET for stdout (color_for 1);
                    # E_BOLD/E_RED/E_CYAN/E_RESET for stderr (color_for 2);
                    # [Round 2, R208/R209/R115: RICH_OUT = TTY_OUT && TERM!=dumb. BOLD/RESET are set only
                    #  when RICH_OUT && color_for 1. E_BOLD/E_CYAN only when RICH_ERR && color_for 2. On a
                    #  plain stderr, forced color (FORCE_COLOR non-0) may set only E_RED/E_RESET, and those
                    #  wrap only the "Error:"/"Warning:" prefix. A plain stdout is never styled.]
                    # RICH_ERR = TTY_ERR && TERM!=dumb && -z TURSO_LATENCY_ACCESSIBLE;
                    # ANIMATE = RICH_ERR && [ -t 0 ] && -z CI && -z OPT_JSON   (NOT gated on NO_COLOR: R207)
                    # GLYPH_ERR = '✗' if RICH_ERR else 'Error:'  (R205); ELLIPSIS = '…' if RICH_ERR else '...'
outf <fmt> [args]   # printf to stdout; `2>/dev/null || exit 0` so a closed pipe ends quietly (R341)
errf <fmt> [args]   # printf to stderr; becomes a no-op when OPT_JSON is set (R253; wired in C3)
die <exit> <reason> <headline> [<recovery-label> <recovery-cmd>]
                    # stop_spinner; human: "<GLYPH_ERR> <headline>" (glyph red if color),
                    # then "\n<label>:\n    <cmd>" (cmd cyan when color, R201/R276/R280), to stderr;
                    # [C3 adds: with OPT_JSON, one compact JSON error line to stderr]; exit <exit>
cleanup             # trap - EXIT INT TERM HUP PIPE; kill "${PIDS[@]}"; stop_spinner;
                    # [ -n "$TEMP_DIR" ] && rm -rf "${TEMP_DIR:?}"
trap cleanup EXIT; trap 'errf "Canceled.\n"; exit 130' INT; trap 'exit 143' TERM
trap 'exit 129' HUP; trap 'exit 0' PIPE                       # R335 R364 R416 R341 R337
                    # [Round 2, R294/R328: INT becomes
                    #  trap 'stop_spinner; errf "Canceled.\nNothing was changed.\n"; exit 130' INT
                    #  (progress clears before the message; the probes are reads, so nothing changed).
                    #  All traps are installed inside main(), not at file top level (A2).]
make_temp           # TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/turso-latency.XXXXXX") || die 1
                    #   temp_dir_unavailable "Couldn't create a temp directory in ${TMPDIR:-/tmp}."
                    #   [Round 2 re-check, R285: "Couldn't", because the attempt failed.]
                    # then mkdir "$TEMP_DIR/res" "$TEMP_DIR/raw" "$TEMP_DIR/err"
atomic_write <path> <value>   # printf '%s\n' v > "<dir>/.<base>.tmp" && mv -f it "<path>" (R351;
                    # deterministic dot-name is safe: the dir is mktemp-private, mode 0700)
display_width <s>   # printf %s "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
                    # (code points; locale-independent; every region name is width-1)
pad_to <s> <cols>   # printf '%s%*s' "$s" $((cols - $(display_width "$s"))) ''   (R210)
```

**Main wiring added in the Wave A commit** (top-level code, before any work):

```bash
parse_args "$@"; resolve_modes
[ -n "$OPT_HELP" ]    && { usage; exit 0; }          # help wins (R083, R086)
[ -n "$OPT_VERSION" ] && { printf '%s\n' "$VERSION"; exit 0; }
[ -n "$USAGE_ERR" ]   && die 2 "$USAGE_REASON" "$USAGE_ERR" "See all options" "$PROG --help"
make_temp                                            # was :61-62
... body ...  (curl uses --max-time "$OPT_TIMEOUT" at :71)
exit 0                                               # explicit; :219 rm -rf deleted (EXIT trap owns it)
```

**`usage`** writes to stdout (R083, R087, R231). Each line ships in the same commit as its behavior (R023, R437):

```
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
```

Later commits add Notes lines with their behavior: B4 "Results go to stdout; progress goes to stderr. Honors NO_COLOR, FORCE_COLOR and TURSO_LATENCY_ACCESSIBLE=1"; B5 "A failed probe is retried once"; C1 "When stdout is not a terminal the table is tab-separated"; C2 exit codes; C3 adds the `--json` option and its example.

**Round 2 correction to the Notes lines (R095, R232, R092).** The B4 sentence above would be one 108-column line (measured: `awk '{print length}'` under `en_US.UTF-8` on the proposed text in `/tmp/cli-bp/tlc-r2/help-lines.txt`), and it lacks the Oxford comma. B5's "retried once" also contradicts the Wave A line "Each region gets one plain-HTTP GET". So no Notes line is appended as written above. The Notes block reads as follows after C2, with each line landing in the commit noted on the right (that annotation is not part of the help text). Every line measures 79 columns or fewer (same method):

```
Notes:
  Each region gets a plain-HTTP GET to http://region.turso.io:8080/ with a      (A; "one" dropped in B5)
  fly-prefer-region header. All regions run in parallel, and a failed probe      (B5 rewrites A's line)
  is retried once.                                                               (B5)
  Results go to stdout; progress goes to stderr. When stdout is not a            (B4; second clause C1)
  terminal, the table is tab-separated.                                          (C1)
  Honors NO_COLOR, FORCE_COLOR, CI, CLAUDECODE, and TURSO_LATENCY_ACCESSIBLE=1.   (B4; CI/CLAUDECODE B10)
  An empty variable counts as unset, and options win over variables. Nothing     (B15)
  is saved between runs.                                                         (B15)
  TURSO_LATENCY_COMPAT_TABLE=1 restores the 1.x table until 3.0.0.               (C1 addendum 2)
  Exits 0 when every region was measured, 1 when any region failed, 2 on a       (C2, per D2)
  usage error.                                                                   (C2)
```

The Options section is rendered from the A2 metadata in long-name order. After C4 it is `-d, --debug`, `--fields <FIELDS>`, `-h, --help`, `--json`, `--no-color`, `--non-interactive`, `--timeout <DURATION>`, `-v, --version`. The longest rows are `--fields` and `--timeout` at 79 columns (measured, same method). A-T15 guards the 80-column limit from Wave A on.

**What the Wave A commit fixes by itself:** finding 2 (R012 R055 R064 R081 R083 R084 R086 R087 R304 R337 R379 R411) and finding 6 (R335 R341 R364 R416, and R351 via mktemp). The usage error text follows the guide's Usage class:

```
Error: Unknown option --jsno for turso-latency-checker.

See all options:
    turso-latency-checker --help
```

With a TTY on stderr, the prefix is `✗` instead of `Error:`. An unexpected positional uses `Unknown command foo for turso-latency-checker.`, reason `unknown_command`. Both exit 2.

Compatibility note for the release notes: invocations that pass arguments now exit 2, where they used to be ignored. No caller passes any (census in the verified findings). This ships in 1.2.0 as an R064/R013 MUST fix.

**Wave A tests** (U2, `test/turso-latency-checker.bats`; "no probes" means `[ ! -s "$STUB_CURL_LOG" ]` and `find "$TMPDIR" -mindepth 1` is empty):

| Test name | Assertion |
|---|---|
| `A-T1 help: --help, -h and help print usage to stdout, exit 0, no probes` | for each arg: `status -eq 0`; `${lines[0]} == "Usage: turso-latency-checker [options]"`; `stderr` empty; no probes |
| `A-T2 help wins over --version and over unknown options` | `--version --help` and `--bogus --help` → status 0, `lines[0]` is the Usage line |
| `A-T3 version: -v and --version print only the version` | `output == "$(sed -n 's/^VERSION=\([0-9.]*\).*/\1/p' "$SCRIPT")"`; matches `^[0-9]+\.[0-9]+\.[0-9]+$`; equals `jq -r .version package.json` (`skip` when package.json is 0 bytes, pending D4); no probes |
| `A-T4 unknown option exits 2 before any probe` | `--jsno`: status 2; stdout empty; `stderr_lines[0] == "Error: Unknown option --jsno for turso-latency-checker."`; stderr contains `    turso-latency-checker --help`; no probes |
| `A-T5 unexpected positional exits 2` | `foo` and `-- foo`: status 2; stderr has `Unknown command foo for turso-latency-checker.` |
| `A-T6 --timeout validation` | `--timeout 0`, `--timeout abc`, a bare `--timeout`: status 2, stderr names `--timeout`. `--timeout 5s` and `--timeout=1.5`: status 0, and every stub-log line contains `--max-time 5` / `--max-time 1.5` |
| `A-T7 temp dir: under TMPDIR via mktemp, removed after the run` | with `STUB_CURL_SLEEP=1`, poll (bounded 5 s) until `"$TMPDIR"/turso-latency.*` exists, and assert no `/tmp/turso_latency_<pid>`; after exit, `$TMPDIR` is empty |
| `A-T8 SIGTERM exits 143, removes temp dir, leaves no probe processes` | `STUB_CURL_SLEEP=30 STUB_CURL_PIDS=$f`; start in background; wait (bounded 5 s) for 35 pids in `$f`; `kill -TERM`; `wait` → 143; `$TMPDIR` empty; within 2 s no pid in `$f` passes `kill -0` |
| `A-T9 SIGINT exits 130 and prints Canceled.` | same as A-T8, but the script must start with SIGINT not ignored (a backgrounded non-interactive child inherits SIG_IGN, which bash cannot trap): launch with `python3 -c 'import os,signal,sys; signal.signal(signal.SIGINT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' "$TLC_BASH" "$SCRIPT" 2>"$e" &`; `kill -INT`; status 130; `$e` ends with `Canceled.` (Round 2: the last two lines of `$e` are `Canceled.` and `Nothing was changed.`, and `$e` has no `\r` before them) |
| `A-T10 closed stdout ends quietly with exit 0` | `STUB_CURL_SLEEP=0.2`; run `"$TLC_BASH" "$SCRIPT" 2>"$e" \| true` and read `PIPESTATUS[0]` → 0; `$e` has no `Broken pipe` and no `write error`; `$TMPDIR` empty |

### Wave A additions (Round 2): commit A2, right after A and before B1

Owner U1 (script) and U2 (tests). It touches the same helper block as A, so it lands as its own red-first pair to keep A reviewable. Line numbers refer to HEAD.

**A2. Option metadata, sourceable parser, every usage problem at once, boolean/repeat semantics, error spacing** (R087 R063 R100 R393 R302 R258 R068 R069 R065 R392 R282 R116 R408 R412 R095)

- **Option metadata (R087, R063, R107 prep).** Add one `OPTS` string with one record per option: `long|short|hint|default|repeat|summary`. It is newline-separated and read with `while IFS='|' read -r …`, which is bash-3.2 safe. `usage` renders its Options section from these records in long-name order (R089). `parse_args` keeps its case arms, but reads value hints, defaults and repeat rules from `OPTS`, and A-T12 ties the two together. C4's `--help --json` renders from the same records, so help and JSON help cannot drift.
- **Sourceable without running (R100, R393).** Wave A's top-level wiring becomes `main() { … }`, and all traps are installed inside `main`. The file ends with `if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then main "$@"; fi`. A test can then `source "$SCRIPT"` and call `parse_args` on each help example without probing anything. The `:-$0` fallback keeps `bash < script` working. This is not a new env var or option, so nothing is added to the contract (R382).
- **Every usage problem at once (R302, R258).** `parse_args` appends each problem to `USAGE_ISSUES` as `<token>|<reason>|<message>` and keeps scanning; help still wins (R083).
  - One issue: the Wave A headline is unchanged.
  - 2 or more issues: the headline is `Can't measure latency. <n> inputs are invalid.` (Reference J Usage formula), then at most 5 issue rows indented 2 spaces (`  --timeout 0: Use a positive duration, such as 5s.`, `  --jsno: Unknown option.`), then `  and <k> more` if needed, then the `See all options:` recovery. The reason is `invalid_arguments` and the exit code is 2.
  - C3 carries every issue in `data.issues`.
- **Booleans (R068).** `--no-color`, `--no-color=true` and `--no-color=false` all parse; `=false` means "no override", and the next precedence level applies. Any other `=<v>` on a boolean is `invalid_arguments`: "Use --no-color=true or --no-color=false." The same arm shape applies to `--non-interactive` (B10) and `--json` (C3) when they land.
- **Repeats and empties (R069, R065).** `--timeout` is last-wins. `--timeout=` and `--timeout ''` are usage errors. Each option's repeat rule is recorded in `OPTS` (C4 publishes it). Prefixes never match: `--time 5s` is an unknown option.
- **Presentation and cancel fixes.** These are corrected in the Wave A API above (R208 styling, R294 cancel copy); A2 adds their tests.
- **Error spacing (R282).** `errf` sets `ERR_DIRTY=1`. `die` prints one blank line first when `ERR_DIRTY` is set, so an error never runs into earlier stderr output.
- **One mode and theme module (R116, R408, R412).** `[ -t N ]`, `$CI`, `$CLAUDECODE`, `$TERM` and `\033[` appear only between the helper-block markers. A-T14 enforces this.

**A2 tests** (U2, `test/turso-latency-checker.bats`):

| Test name | Assertion |
|---|---|
| `A-T11 every help example and printed self-command parses without running (R100, R393)` | in a subshell, `source "$SCRIPT"` (the guard keeps `main` from running). Collect: every line under `Examples:` in `run_cli --help` stdout that starts with `    turso-latency-checker`; every line beginning `turso-latency-checker` inside README.md's fenced code blocks; and the recovery command that A-T4 prints. For each one, `read -ra argv` the words after the program name, call `parse_args`, and assert `[ -z "$USAGE_ERR" ]` and an empty `USAGE_ISSUES`. Also assert that at least 2 commands were checked and that `[ ! -s "$STUB_CURL_LOG" ]` (nothing ran). The test does not fix the example count, so C3's `turso-latency-checker --json` example is covered once it lands, without editing this file |
| `A-T12 entry points, short/long forms, repeats and booleans (R392, R393, R065, R068, R069, R087)` | `-h`, `--help` and `help` give byte-identical stdout, and `-v` equals `--version`. Headings appear in the order Usage, `Options:`, `Examples:`, `Notes:`, `Learn more:`. The Options section's long names equal the `OPTS` long names, in order (source the script to read `OPTS`). `--timeout 1s --timeout 2s`: every stub-log line contains `--max-time 2`. `--time 5s` → status 2 with `Unknown option --time`. `--no-color=true` and `--no-color=false` → status 0. `--no-color=maybe` and `--timeout=` → status 2 |
| `A-T13 every usage problem is reported at once (R302)` | `--timeout 0 --jsno foo`: status 2; stdout empty; `stderr_lines[0] == "Error: Can't measure latency. 3 inputs are invalid."`; then 3 rows starting with two spaces, naming `--timeout 0`, `--jsno` and `foo`; then the `See all options:` recovery. Seven bad options give 5 rows plus `  and 2 more`. No probes |
| `A-T14 mode, theme and color checks live only in the helper block (R116, R408, R412)` | static: strip the lines between `# ---- cli helpers` and `# ---- end cli helpers ----`, then `grep -nE '\[ -t [012] \]\|\$\{?(CI\|CLAUDECODE\|TERM)\b\|\\033\['` on the rest finds nothing. Signal names in `trap … TERM` don't match, because the pattern requires `$` |
| `A-T15 help fits 80 columns (R095)` | `run_cli --help`; `${lines[0]} == "Usage: turso-latency-checker [options]"` (Round 2 re-check: without this the test passes at HEAD, whose 80-column rules fit, and that breaks red-first); `printf '%s\n' "$output" \| LC_ALL=C tr -d '\200-\277' \| awk 'length>80'` prints nothing (counts code points, the same method as `display_width`) |
| `A-T16 every command the CLI prints uses long options (Round 2 re-check; R099, R047)` | same collection as A-T11, and assert that at least 2 commands were collected. No collected command has a word matching `^-[a-zA-Z]$`. Static: `! grep -nE '"curl -[a-zA-Z]' "$SCRIPT"`, which guards the printed gateway recovery in C2 |

---

## 3. Wave B: compatible fixes, grouped by file

### File `turso-latency-checker.sh` (owner U1). One commit per item, in this order. Line numbers refer to HEAD.

**B1. Probe failures are detected; no fake latencies** (finding 1; R003 R017 R275 R194)

- `:64-80` rewrite `measure_latency` (runs as a background subshell):
  - Set `trap 'kill "$CPID" 2>/dev/null; exit 143' TERM` once at the top.
  - Loop over attempts 1..2. Each attempt runs `curl -sS -o /dev/null -w '%{time_total}' --max-time "$OPT_TIMEOUT" -H "fly-prefer-region: $loc" "$PROBE_URL" >"$TEMP_DIR/raw/$loc" 2>"$TEMP_DIR/err/$loc" & CPID=$!; wait "$CPID"; rc=$?`.
  - Declaring and assigning separately removes SC2155, and making curl its own job lets cleanup kill it (R364).
  - Retry belongs to B5. Until B5 lands, run 1 attempt.
- `:75` replace bc with `ms=$(LC_ALL=C awk -v t="$(cat "$TEMP_DIR/raw/$loc")" 'BEGIN{ if (t !~ /^[0-9]*\.?[0-9]+$/) exit 1; printf "%d", t*1000 }')`. This fixes `.5000` → empty and removes the bc dependency. `LC_ALL=C` guards comma-decimal locales.
- `:76/:78` become `atomic_write "$TEMP_DIR/res/$loc" "$ms"` when `rc -eq 0` and `ms` matches `^[0-9]+$`. Otherwise `atomic_write "$TEMP_DIR/res/$loc" "ERROR $rc"`.
- `:131-137` and `:181-187` merge into one classification loop over `LOCATIONS`:
  - missing file, empty value or `ERROR*` → `FAILED+=("$loc")`
  - an integer → `OK_ROWS+=("$loc $v")`
  - A missing file now counts as failed and is never silently dropped (R017).
- `:140` (SC2207) becomes `sorted=(); while IFS= read -r l; do sorted+=("$l"); done < <(printf '%s\n' "${OK_ROWS[@]}" | sort -n -k2)`, guarded by `[ ${#OK_ROWS[@]} -gt 0 ]`.
- `:143-145` duplicate `:199-201`: compute `fastest` once.
- Visible change: dead regions move from the table to the failure list. The exit code is unchanged (C2 owns that).

Tests (U2):

| Test name | Assertion |
|---|---|
| `B1-T1 probe: curl failure is reported as failed, never as a latency` | `STUB_CURL_FAIL="bog:28 gru:7"` (the stub prints a time_total value, as real curl does, then exits rc). No stdout table row starts with `bog` or `gru`; both appear under the failure block; 33 table rows |
| `B1-T2 probe: sub-millisecond time renders as 0ms, never blank` | `STUB_CURL_TIME=0.000500`. Every row's latency field matches `^[0-9]+ms$`; 35 rows; no row with an empty latency |
| `B1-T3 probe: works when bc is missing` | `PATH="$BATS_TEST_DIRNAME/fixtures/nobc:$PATH"` (a `bc` stub that exits 127). Same assertions as B1-T2; `! grep -qw bc "$SCRIPT"` |

**B2. Bounded wait, PIDs and atomic results** (finding 5; R019 R313 R351 R017)

- `:100-103` becomes `measure_latency "$loc" & PIDS+=($!)`.
- `:105-121` replace `while true` and `ls | wc -l` with a loop bounded by a deadline:
  - `max_ticks=$(LC_ALL=C awk -v t="$OPT_TIMEOUT" 'BEGIN{printf "%d",(2*t+2.5)*10}')`. This covers 2 attempts, the 0.5 s backoff and 2 s of slack.
  - Each tick counts live PIDs with `kill -0`, breaks at 0, and on the deadline runs `kill "${PIDS[@]}"` and breaks.
  - Then `wait` (bounded: every job has exited or been TERM'd, and its trap kills its curl).
  - The progress count comes from `[ -f "$TEMP_DIR/res/$loc" ]` over `LOCATIONS`, which never sees the dot-temp files.
- Cause for a region with no result file: `no result within <N>s`.
- The `-eq` hang at `:114` and stale-dir reuse are gone (mktemp comes from Wave A).

Tests:

| Test name | Assertion |
|---|---|
| `B2-T1 wait: bounded when a probe hangs` | `STUB_CURL_HANG=ams` (the stub ignores `--max-time` and sleeps 60); run under `timeout 20` with `--timeout 1`. Finishes with `SECONDS -lt 10`; `ams` is in the failure block with `no result within`; status 0 (Round 2: runs via `run_cli_1x` and asserts no status; C2's tests own failure exit codes, so this file needs no phase-2 edit) |
| `B2-T2 wait: unwritable TMPDIR fails fast` | `TMPDIR=/nonexistent/x`, under `timeout 10`. Status 1; stdout empty; stderr `Error: Couldn't create a temp directory in /nonexistent/x.` |
| `B2-T3 results: never written with a bare redirect` | static: `! grep -nE '> *"\$TEMP_DIR/(res/)?\$loc' "$SCRIPT"`; `grep -q 'atomic_write' "$SCRIPT"` (the race itself cannot be forced from a test; B1-T2's no-blank-row check is the behavioral proof) |

**B3. Streams: progress and noise leave stdout** (finding 3, compatible part; R016 R177 R173)

- `:95-98` banner becomes one stderr context line, `errf 'Measuring latency to %d Turso regions via %s%s\n' "$total" "$PROBE_HOST" "$ELLIPSIS"`. The `=====` underline is dropped.
- `:123`, `:126` blank line and `RESULTS (sorted by latency)` heading: delete. The stderr completion line replaces them (B6).
- `:127/:129` dashed rules: print them only when `TTY_OUT`. They are decoration and never go into a pipe.
- `:128` header row and `:148-179` rows stay on stdout with unchanged text and order.
- `:189-195` failure block, `:209-210` fastest line and `:213` no-success line **stay on stdout in Wave B**. Moving them is the C1 contract change.
- `:216` trailing blank line: delete.

Test:

| Test name | Assertion |
|---|---|
| `B3-T1 streams: piped stdout holds no banner, spinner or carriage return` | `run --separate-stderr`. `[[ $output != *$'\r'* ]]`; `[[ $output != *Measuring* ]]`; stdout `lines[0]` is the `ID      LOCATION …` header; `stderr` contains `Measuring latency to 35 Turso regions via region.turso.io:8080...` (ASCII `...`, because stderr is not a TTY) |
| `B3-T2 contract: the 1.x piped header and rows are unchanged (Round 2; R384, R402)` | runs via `run_cli_1x` with `STUB_CURL_TIME=0.050`. After `sed $'s/\033\\[[0-9;]*m//g'` (1.x always emitted bold on the fastest row), the stdout header equals `printf '%-6s  %-36s  %11s  %s' ID LOCATION LATENCY GATEWAY`. Each data row equals what HEAD's `:175` printf prints for that region, or HEAD's `:172` three-space variant for gru, bog and qro, with `50ms` and `✓`/space. B4's display-width padding yields the same bytes. The `Fastest region:` line is unchanged after stripping |

**B4. Spinner, color and table rendering by mode** (findings 7, 8, and the TTY part of 9; R328 R118 R120 R121 R115 R199 R200 R201 R204 R206 R207 R209 R210 R181 R191 R198)

- `:106-121` spinner: frames go to stderr only when `ANIMATE`, as `printf '\r%s Measuring%s %d of %d ' "${SPIN[i]}" "$ELLIPSIS" "$done" "$total" >&2`. `stop_spinner` prints `\r\033[K` to stderr only when `ANIMATE` and a frame has been drawn.
  - When not `ANIMATE`, there is no output per tick. The B3 context line is the single plain line for the phase (R328, R121).
  - This deliberately deviates from the verifier's refined fix: NO_COLOR must not stop the animation (R207).
- `:55-58` constants are deleted (Wave A `resolve_modes` owns styling).
- `:163/:166/:172/:175` collapse into one `print_row`:
  - `outf '%s%-6s%s  %s  %11s  %s\n' "$B" "$loc" "$R" "$(pad_to "$name" 36)" "${ms}ms" "$gw"`.
  - `B`/`R` are `BOLD`/`RESET` on the fastest row only, otherwise empty. Bold applies to the ID cell only (R200). There is no cyan (R201), and styles are passed as `%s` arguments, never in the format string (R199).
- `:161-177` the gru/bog/qro case arms are deleted, because `pad_to` measures display width (R210).
- `:155-156` truncation is dead code (the longest name, `Los Angeles, California (US)`, is 28 characters, counted from `:15-50`) and is deleted (R191).
- `:82-92` `is_gateway` becomes a predicate (`return 0`/`1`, prints nothing).
  - `gw='✓'` or `' '`. Keep the glyph in the 1.x padded table, because that table is still the piped contract until C1.
  - With `TURSO_LATENCY_ACCESSIBLE` set, `gw` is `yes`/`no` (R186). This is a new opt-in mode, so it is compatible.
  - `:205` becomes `if is_gateway "$fastest"; then`.
- `:210` `echo -e` becomes `outf 'Fastest region: %s%s%s (%s) - %sms%s\n' "$BOLD" "$loc" "$RESET" "$name" "$ms" "$gwinfo"`. The text is byte-identical once styling is stripped.
- Add the help Notes line for streams and environment.

Tests:

| Test name | Assertion |
|---|---|
| `B4-T1 color: no escape bytes when piped, with NO_COLOR, --no-color or TERM=dumb` | four runs; no `$'\033'` in stdout or in stderr |
| `B4-T2 color: only a rich stdout is styled; forced color on a pipe tints only the Error: prefix` (Round 2: corrected. The round-1 row asserted bold on a piped stdout under `FORCE_COLOR=1`, which R208/R209 forbid: a pipe is plain presentation) | `STUB_CURL_TIMES="ams:0.010"` (others 0.050). Under `run_tty`, the transcript contains `$'\033[1m'ams$'\033[0m'` and has no `\033[1;36m` or `\033[0;36m`. Its table lines, after `sed $'s/\033\\[[0-9;]*m//g'`, equal the table lines of a `NO_COLOR=1` `run_tty` run (R207). Piped with `FORCE_COLOR=1` (`run_cli`): stdout has no `$'\033'`. With `FORCE_COLOR=1`, `--jsno` gives `stderr_lines[0] == $'\033[31mError:\033[0m Unknown option --jsno for turso-latency-checker.'`, and the recovery command line carries no escape. `FORCE_COLOR=0` under `run_tty` → no escapes |
| `B4-T3 tty: spinner animates on a TTY, not in accessible mode or CI` | `run script -q /dev/null "$TLC_BASH" "$SCRIPT"` (BSD `script`; stdout and stderr merge). The transcript contains `$'\r'` and `⠋`. With `TURSO_LATENCY_ACCESSIBLE=1`, and separately with `CI=1`: no `$'\r'`, no Braille glyph |
| `B4-T4 table: non-ASCII names align with ASCII rows` | rows for ams, gru, bog, qro: `printf %s "${line%%ms*}ms" \| LC_ALL=C tr -d '\200-\277' \| wc -c` is 57 for every row (6+2+36+2+11) |
| `B4-T5 gateway: accessible mode prints words, not glyphs` | `TURSO_LATENCY_ACCESSIBLE=1`: the ams row ends in `yes` and the arn row ends in `no`; no `✓` in output |

**B5. Retry transient failures once** (finding 12; R314, R313 already satisfied by `--max-time`)

- In `measure_latency`: if `rc` is in `6 7 28 35 52 56` and this is attempt 1, then `: >"$TEMP_DIR/.retrying"`, `sleep 0.5`, and retry. Record only the last attempt's timing.
- The wait loop prints `Retrying automatically%s\n` with `$ELLIPSIS` to stderr **once**, the first time `.retrying` appears (R219 verbatim phrase). In `ANIMATE` mode it appears as the spinner label instead.
- Add the help Notes line `A failed probe is retried once.`
- Keep http. Switching to https would add TLS setup to the measured number.

Test:

| Test name | Assertion |
|---|---|
| `B5-T1 retry: a transient failure is retried once and the second timing is kept` | `STUB_CURL_FAIL_ONCE="ams:7"` and `STUB_CURL_TIMES="ams:0.020"`. ams row shows `20ms`; `grep -c '^ams ' "$STUB_CURL_LOG"` is 2; stderr contains `Retrying automatically...` exactly once. `STUB_CURL_FAIL="arn:3"` (rc 3 is not transient): 1 arn call, arn failed |

**B6. Failure copy names host, cause and count** (finding 11, compatible part; finding 13; R275 R276 R277 R285 R292 R185 R219 R231 R232)

- `:189-195` on stdout (relocated in C1):
  - `Couldn't reach %d regions via region.turso.io:8080` as a plain heading (Round 2 re-check: no trailing colon, R183, R184), then one row per failed region: `- <id> (<name>): <cause>`.
  - Cause map: `28` → `timed out after <T>s`; `6` → `DNS lookup failed`; `7` → `connection refused`; missing → `no result within <N>s`; other → `curl exit <rc>: <first line of err/<loc>, with "curl: (n) " stripped>`. Never guess a cause (R275).
  - List **every** failed region. It is the result, not a validation issue list, so R302's 5-row cap does not apply, and before C3 there is no machine channel that would carry the rest.
- `:115` `Complete!` is deleted. After the wait, write to stderr `Measured 35 regions.`, or `Measured %d of %d regions. %d failed.` (the guide's Partial headline, R232 with no `!`).
- `:213` `No successful connections to any region.`: unchanged in Wave B (C2 rewrites and relocates it).

Test:

| Test name | Assertion |
|---|---|
| `B6-T1 failures: each failed region names its cause` | `STUB_CURL_FAIL="bog:28 gru:7 qro:6 scl:56"`. stdout contains the line `Couldn't reach 4 regions via region.turso.io:8080`, `- bog (Bogotá, Colombia): timed out after 3s`, `- gru (São Paulo, Brazil): connection refused`, `- qro (Querétaro, Mexico): DNS lookup failed`, `- scl (Santiago, Chile): curl exit 56: Recv failure` (the stub writes `curl: (56) Recv failure` to stderr). stderr contains `Measured 31 of 35 regions. 4 failed.` |
| `B6-T2 copy: no banner exclamation, all-caps heading or "Failed to connect"` | `! grep -nE 'Complete!\|RESULTS \(\|Failed to connect\|=====' "$SCRIPT"`; full-success stderr ends with `Measured 35 regions.` |

**B7. Dependency preflight and shebang** (finding 14, script part; R007 R302)

- `:1` becomes `#!/usr/bin/env bash`. The bash 3.2 floor still holds, because env resolves to `/bin/bash` on stock macOS.
- After the help/version/usage-error dispatch and before `make_temp`, collect every missing tool from `curl awk mktemp` in one pass. Then `die 1 missing_dependency "Can't measure latency without <list>. Install it and rerun turso-latency-checker."`. There is no recovery command because install steps vary by OS (R280 plain sentence).

Test:

| Test name | Assertion |
|---|---|
| `B7-T1 preflight: missing curl fails fast with exit 1` | `PATH` is a temp dir of symlinks to `awk cat mkdir mktemp mv rm sleep sort tr wc` (no curl). Status 1; stdout empty; stderr `Error: Can't measure latency without curl. Install it and rerun turso-latency-checker.`; `$TMPDIR` empty |
| `B7-T2 script parses under bash 3.2 and uses env bash` | `head -1 "$SCRIPT"` equals `#!/usr/bin/env bash`; `/bin/bash -n "$SCRIPT"` exits 0 |

### Round 2 additions to `turso-latency-checker.sh` (owner U1): B8–B12, landed after B7 in this order

**B8. Plurals, raw unknown codes, a single "still working" line, glossary nouns** (R217 R417 R374 R329 R423)

- **Plurals (R217, R417).** Add a shared `plural <n> <one> <many>` formatter, and send every count in output through it. B6's heading reads `Couldn't reach 1 region via region.turso.io:8080` for one failure. Round 1's `Couldn't reach %d regions` printed "1 regions".
- **Raw unknown codes (R374).** `:50` `*) echo "Unknown location"` becomes `*) printf '%s\n' "$1"`. The arm is unreachable at HEAD: the 35 `LOCATIONS` codes and the 35 case arms are identical (measured: `diff` of the two extracted lists is empty, and all 16 `GATEWAY_REGIONS` are in `LOCATIONS`). So this is hardening for a future region added to one list only.
- **Still working (R329).** In the B2 wait loop, when elapsed time passes `OPT_TIMEOUT + 1` seconds (rounded up), print once to stderr: `Still measuring <n> regions. Most runs finish within <T> seconds.`
  - `<n>` counts regions without a result (through `plural`), and `<T>` is `OPT_TIMEOUT + 1`.
  - In `ANIMATE` mode, `stop_spinner` runs first and the spinner resumes on the next tick.
  - The line goes through `errf`, so it is silent under `--json`.
- **Glossary nouns (R423).** Output uses "region" for a region and "location" only for its city name, and never "test" for a probe. The 1.x strings `Running tests:` (:106, :112, :115) and "all Turso locations" (:97) are already deleted by B3/B4; B8 adds the lint test. U3 adds the glossary to README (section 3, U3 table).

| Test name | Assertion |
|---|---|
| `B8-T1 one failed region reads in the singular` | via `run_cli_1x`, `STUB_CURL_FAIL="bog:3"`: stdout contains the line `Couldn't reach 1 region via region.turso.io:8080`; stderr contains `Measured 34 of 35 regions. 1 failed.` |
| `B8-T2 every region has a name; unknown codes render raw` | in a subshell, `source "$SCRIPT"`. For each `LOCATIONS` code, `get_location_name` returns something other than the code. `get_location_name zzz` prints `zzz`. Every `GATEWAY_REGIONS` code is in `LOCATIONS`. `! grep -n 'Unknown location' "$SCRIPT"` |
| `B8-T3 a slow run says so once` | `STUB_CURL_HANG=ams`, `--timeout 1`, under `timeout 20`: stderr contains `Still measuring 1 region. Most runs finish within 2 seconds.` exactly once |
| `B8-T4 output uses the glossary nouns` | `! grep -nE 'Turso locations\|Running tests\|fastest location' "$SCRIPT"` |

**B9. The TTY table fits the terminal width** (R191 R210 R211 R401)

- **Width (R210).** `resolve_modes` adds `COLS_OUT`: when `TTY_OUT`, the second field of `stty size <&1` (measured on stdout, the destination stream), otherwise 80. It lives in the helper block (A-T14).
  - **Round 2 re-check (measured with `/tmp/cli-bp/tlc-r2/probe/run.sh` under bash 3.2 and 5.3).** Inside `$(…)`, `<&1` is the substitution's pipe, so `x=$(stty size <&1)` fails with `stty: stdin isn't a terminal`. Read the size as `{ sz=$(stty size <&3 2>/dev/null); } 3>&1`. A width of 0 or a failed read also means 80: a `script` PTY under a non-TTY parent reports `0 0`, which would otherwise put every `run_tty` test in the record layout.
- **Column sizing on a TTY.** When `TTY_OUT`, `print_row` sizes the Location column as `L = min(36, COLS_OUT - 26)`. 26 is ID 6, Latency 7 (right-aligned, the width of its header), Gateway 7, and three 2-space gaps.
- **Shortening (R191).** A name wider than `L` is cut to `L-1` display columns plus `…`. Location is the descriptive column, so it is shortened first; IDs and latencies are never cut. Cut by display width with `display_width`, dropping a whole UTF-8 sequence at a time.
- **Narrow terminals.** Below 34 columns (`L < 8`), each region prints as a record: `<id>  <latency>` plus `  gateway` when it is one, then the location on the next line, indented 2.
- **Piped output is unaffected.** The piped (1.x, then C1 TSV) layout never depends on width (R189, R191).

| Test name | Assertion |
|---|---|
| `B9-T1 TTY table at 40, 80 and 120 columns (R401)` | `run_tty_cols <n>`, a U2 helper: `script -q /dev/null "$TLC_BASH" -c 'stty cols "$1" rows 60; exec "$2" "$3"' _ <n> "$TLC_BASH" "$SCRIPT"`, then `strip_ansi` and drop spinner frames. At 40: every table line is at most 40 display columns, all 35 rows keep their full ID and `<n>ms`, and at least one row ends its Location in `…`. At 80 and 120: no `…`, and each Location is the full name. A piped run with `COLUMNS=40` exported still matches B4-T4's widths |
| `B9-T2 a very narrow TTY prints records` | at 30 columns: no line over 30 display columns; a line matches `^ams +[0-9]+ms +gateway$`, and the next line is `  Amsterdam, Netherlands` |
| `B9-T3 an unknown width falls back to 80 (Round 2 re-check)` | `run_tty_cols 0` (the PTY reports `0 0`): the ams row matches `^ams +Amsterdam, Netherlands +[0-9]+ms`, no line ends in `…`, and no line matches `^ams +[0-9]+ms` |

**B10. Non-interactive inputs: `--non-interactive` and agent detection** (R062 R113 R117 R328 R403 R068)

- **The option (R062, R068).** Add the parser arm `--non-interactive`, with `=true` and `=false` per A2. It is a Reference B global option. Its `OPTS` row renders as `      --non-interactive     Never animate progress (the CLI never prompts)` (74 columns, measured). Its behavior lands in the same commit (R437).
- **Interactive mode (R113, R117).** `resolve_modes` sets `INTERACTIVE` when `[ -t 0 ] && [ -t 2 ]` and `CI`, `CLAUDECODE`, `OPT_NON_INTERACTIVE` and `OPT_JSON` are all empty. `ANIMATE` becomes `RICH_ERR && INTERACTIVE`, replacing Wave A's `ANIMATE` line.
  - A detected agent is recognized by `CLAUDECODE`, the variable the sibling plans use (`claude-session-search.md:110`). It still gets human output, only without animation (R117).
  - **Round 2 re-check (R113, R117).** `--non-interactive=false` restores animation for a detected agent on a TTY, and for nothing else. The line above made it a no-op under `CLAUDECODE`, which R113 rules out. So `OPT_NON_INTERACTIVE` holds `true`, `false` or empty, and `INTERACTIVE` requires `[ -t 0 ] && [ -t 2 ]`, empty `CI` and `OPT_JSON`, `OPT_NON_INTERACTIVE` not `true`, and either an empty `CLAUDECODE` or `OPT_NON_INTERACTIVE=false`.
- **Help Notes (R080).** The env sentence becomes `Honors NO_COLOR, FORCE_COLOR, CI, CLAUDECODE, and TURSO_LATENCY_ACCESSIBLE=1.` (see the corrected Notes block in section 2).
- **Callers.** None; the option is additive.

| Test name | Assertion |
|---|---|
| `B10-T1 mode matrix: success and failure in every mode (R403)` | Modes: interactive TTY (`run_tty`); stdout redirected (`run_cli`); stdin piped (`run_tty` with `</dev/null` inside the `script` command); `--non-interactive` under `run_tty`; `CI=1` under `run_tty`; `CLAUDECODE=1` under `run_tty`. Run each once with every probe succeeding and once with `STUB_CURL_FAIL_ALL=7`. Assert:<br>- For each case, the exit code is identical across modes. Only the value is left open, so the test survives C2.<br>- `\r` and a Braille frame appear only in the interactive-TTY run.<br>- No output line ends in `?`; no prompt ever appears.<br>- Every success run's output contains an `ams` row and never a `{`.<br>- Under `run_cli`, stdout and stderr are asserted separately, per B3-T1.<br>C3-T12 adds the `--json`-on-a-TTY mode |
| `B10-T2 --non-interactive parses as a boolean` | `--non-interactive=false` under `run_tty` animates; `--non-interactive=maybe` → status 2 |
| `B10-T3 --non-interactive=false restores animation only for a detected agent (Round 2 re-check; R113, R117)` | `CLAUDECODE=1 --non-interactive=false` under `run_tty`: the transcript has `\r` and a Braille frame. `CI=1 --non-interactive=false` under `run_tty`: neither. The `--json` half joins C3-T12: `--json --non-interactive=false` under `run_tty` has neither |

**B11. Failures after an exhausted retry say so** (R316)

- When a region's retry also fails, its failure row ends in `; retried once`, for example `- bog (Bogotá, Colombia): timed out after 3s; retried once`. The row is a status line, so the duration stays compact (R214).
- B6-T1's `contains` assertions still hold.
- C2 adds the matching `Retries` detail row to the total-failure error.

| Test name | Assertion |
|---|---|
| `B11-T1 a retried failure says so; a non-transient one does not` | via `run_cli_1x`, `STUB_CURL_FAIL="bog:28 arn:3"`. stdout contains `- bog (Bogotá, Colombia): timed out after 3s; retried once`. The arn row has no `retried`. `grep -c '^bog ' "$STUB_CURL_LOG"` is 2, and `grep -c '^arn '` is 1 |

**B12. Rich help styling** (R098 R200 R201 R203 R208)

- On a rich stdout with color (`RICH_OUT && color_for 1`), `usage` styles:
  - section headings bold in one accent hue, keeping their colons (`H=$'\033[1;34m'`, basic ANSI per R204);
  - option names bold;
  - example commands cyan at normal weight (R201 command color);
  - the summary line faint (R203).
- Everything else stays at normal foreground.
- On a plain stdout, and when color is only forced onto a pipe, help is fully unstyled (R208).

| Test name | Assertion |
|---|---|
| `B12-T1 help is styled only on a rich terminal` | `run_tty --help`: the transcript contains `$'\033[1;34m'Options:$'\033[0m'`. Its ANSI-stripped, `\r`-free text equals `run_cli --help` stdout. `FORCE_COLOR=1 run_cli --help` stdout has no `$'\033'` |

### Round 2 re-check additions to `turso-latency-checker.sh` (owner U1): B13–B16, landed after B12 in this order

Section 7, "Round 2 re-check", says why each one was added.

**B13. A server-error reply is a failed probe, and one helper maps every failure** (R003 R017 R283 R291 R296 R299 R264). The classification half, B13b, needs D9.

- **Verified at HEAD.** `:71` passes no `-f` and reads no status, so a 502, 503 or 429 reply exits 0 and prints as a measured latency. It can also win `Fastest region`. B1 fixes the curl exit only. What the real gateway replies has not been measured: no live probe ran, so D9 asks the operator.
- **Capture (no D9 needed).** B1's `-w` becomes `'%{time_total} %{http_code}'`, read back with `read -r t code <"$TEMP_DIR/raw/$loc"`. B1's awk check applies to `t`.
- **One mapper (no D9 needed; R296, R264).** `cause_for <rc> <code>` in the helper block sets `CAUSE_TEXT` and `CAUSE_REASON`. B6's cause map moves into it, and C2's shared cause and C3's `error.reason` read from it, so human and JSON conditions cannot drift.
- **Classification, B13b (after D9).** With rc 0 and a code of 5xx, 429 or 000, write `ERROR http <code>`. Every other code counts as measured: the gateway answered, and this plan can't assume which status `GET /` returns.
  - **Failure row.** `- bog (Bogotá, Colombia): HTTP 503`. A status is a detail, never a headline (R283).
  - **Reason.** `api_error` for 5xx and 000 (R299), `rate_limited` for 429 (R291).
  - **Not retried (recorded exception to R314, R422).** Honoring `Retry-After` needs response headers, and the probe discards them. The user impact is that a one-off 503 shows as a failed region until the next run. B5's transient list stays curl exits only.
- **Callers.** None; the failure list keeps B1's shape.

| Test name | Assertion |
|---|---|
| `B13-T1 a 5xx or 429 reply is a failed probe, never a latency (B13b)` | via `run_cli_1x`, `STUB_CURL_HTTP="bog:503 gru:429 arn:404"`. No table row starts with `bog` or `gru`. stdout contains `- bog (Bogotá, Colombia): HTTP 503` and `- gru (São Paulo, Brazil): HTTP 429`. The arn row shows `50ms`. `grep -c '^bog ' "$STUB_CURL_LOG"` is 1 (not retried) |
| `B13-T2 a fast error reply can't win Fastest region (B13b)` | via `run_cli_1x`, `STUB_CURL_HTTP="ams:503"`, `STUB_CURL_TIMES="ams:0.001 arn:0.010"`: the `Fastest region:` line names arn |
| `B13-T3 every cause string lives in the mapper (R296)` | static: strip the helper block as in A-T14, then `grep -inE 'timed out after\|connection refused\|DNS lookup failed'` on the rest finds nothing. `grep -c 'time_total} %{http_code}' "$SCRIPT"` is 1 |

**B14. A rich stderr uses the gutter** (R181 R182 R205)

- **Verified in this plan.** B6's `Measured 35 regions.` and B3's context line read the same on a rich stderr as on a plain one. R205 makes rich success `✓`, R182 gives context a blank gutter, and R181 starts content at column 2.
- `resolve_modes` adds `GLYPH_OK` (`✓ ` when `RICH_ERR`, otherwise empty) and `GUTTER` (two spaces when `RICH_ERR`, otherwise empty).
- The context line, `Retrying automatically…` and `Still measuring …` print with `$GUTTER`. A full success prints `${GLYPH_OK}Measured 35 regions.` A Wave B partial line prints with `$GUTTER`, and C1's `✗` replaces that.
- The helper block gains `row <label> <value>`, `printf '  %-16s%s\n'` (R181 asks for one layout helper). C2's `Retries` row and C1's rich `Fastest` row use it.
- Plain output doesn't change, so B3-T1, B6-T2 and C2-T3 still hold.

| Test name | Assertion |
|---|---|
| `B14-T1 a rich stderr uses the gutter; a plain one reads as sentences` | `run_tty`: the transcript contains `✓ Measured 35 regions.` and a line that starts with two spaces and then `Measuring latency to 35 Turso regions`. `run_cli`: stderr has no `✓`, and its last line is `Measured 35 regions.` `TURSO_LATENCY_ACCESSIBLE=1` under `run_tty`: no `✓` |

**B15. Environment values are strict and documented** (R074 R079 R080 R083)

- **Verified in this plan.** `resolve_modes` tests `-z TURSO_LATENCY_ACCESSIBLE` (section 2), so `TURSO_LATENCY_ACCESSIBLE=0` turns accessible mode on. No help line states empty-value behavior, precedence or persistence.
- **Values.** `1` means on, and empty or unset means off. Any other value adds a `USAGE_ISSUES` row: `Can't use TURSO_LATENCY_ACCESSIBLE=0. Use 1, or leave it empty.` (63 columns, measured), reason `invalid_arguments`, exit 2, before any probe. `--help` and `--version` still win (R083).
- **Standard names stay as they are.** `NO_COLOR`, `FORCE_COLOR`, `CI` and `CLAUDECODE` have no invalid values here (R079).
- **Help Notes.** Gains the empty-value and precedence sentence; see the corrected Notes block in section 2.

| Test name | Assertion |
|---|---|
| `B15-T1 environment values are strict and documented (R074, R079)` | `TURSO_LATENCY_ACCESSIBLE=0`: status 2; `stderr_lines[0] == "Error: Can't use TURSO_LATENCY_ACCESSIBLE=0. Use 1, or leave it empty."`; no probes. With `--help` added: status 0. `TURSO_LATENCY_ACCESSIBLE=` via `run_cli_1x`: the ams row ends in `✓`. `--help` stdout contains `An empty variable counts as unset` |

**B16. `-d, --debug`** (R062 R244 R253 R261 R283 R464)

- **Verified in this plan.** R062's check compares the global option list with Reference B. B10 adds `--non-interactive` but not `--debug`, which sibling plans add (`agent-secrets.md:948`, `doc_classifier.md:145`). The other Reference B rows don't apply; see section 5.
- **Option.** A parser arm with `=true` and `=false` per A2. Its `OPTS` row renders as `  -d, --debug               Show each probe's raw result on stderr` (66 columns, measured), first in the Options list. It behaves the same in every mode (R006).
- **Output.** After the wait and before the results, one stderr line per region in `LOCATIONS` order: `debug: <id> curl_exit=<rc> http=<code> time_total=<t>`. A region with no result file prints `none` for all three values.
- **Writer.** A new `dbg` function bypasses `errf`, because R244 and R253 allow `--debug` lines on stderr under `--json`. They come before any error document (R261). The script never uses `set -x`, and the lines hold no remote text (R283).
- **Callers.** None; the option is additive.

| Test name | Assertion |
|---|---|
| `B16-T1 --debug shows raw results on stderr and changes nothing else` | via `run_cli_1x --debug`, `STUB_CURL_FAIL="bog:28"`, `STUB_CURL_HTTP="gru:503"`. stderr has 35 lines matching `^debug: [a-z]{3} curl_exit=[0-9]+ http=[0-9]{3} time_total=`. The bog line has `curl_exit=28 http=000`, and the gru line has `curl_exit=0 http=503`. Stdout and status equal the same run without `--debug`. `--debug=false` prints no `debug:` line. `--debug=maybe` → status 2 |

### Files `test/` (owner U2): created new, all Wave A/B/C tests

- `test/helpers.bash`, about 40 LOC:
  - `setup` prepends `fixtures/bin` to PATH, sets `TMPDIR=$BATS_TEST_TMPDIR/tmp` and `STUB_CURL_LOG`, and points the proxy env vars at `127.0.0.1:9`.
  - It unsets `NO_COLOR FORCE_COLOR CI TURSO_LATENCY_ACCESSIBLE TURSO_LATENCY_COMPAT_TABLE`.
  - `run_cli` is `run --separate-stderr "${TLC_BASH:-/bin/bash}" "$SCRIPT" "$@"`; `run_tty` wraps BSD `script -q /dev/null`.
- `test/fixtures/bin/curl`, about 50 LOC POSIX sh:
  - It parses `-H "fly-prefer-region: X"`, `--max-time`, `-w`, and appends `"<region> <argv>"` to `$STUB_CURL_LOG`.
  - Knobs: `STUB_CURL_TIME` (default `0.050`), `STUB_CURL_TIMES`, `STUB_CURL_FAIL`, `STUB_CURL_FAIL_ALL`, `STUB_CURL_FAIL_ONCE` (attempt counter under `$BATS_TEST_TMPDIR/attempts/`), `STUB_CURL_SLEEP` (honors `--max-time`, then exits 28), `STUB_CURL_HANG` (ignores it), `STUB_CURL_PIDS`.
  - On failure it prints the time_total value, writes `curl: (<rc>) <msg>` to stderr, and exits rc.
  - It never execs a real curl.
- `test/fixtures/nobc/bc`: 2 lines, exits 127.
- `test/turso-latency-checker.bats`: the test IDs in this plan. Wave C tests land with their C commits.
- **Round 2 file split and helper additions.**
  - **Phase-2 file (U5).** Wave C tests (C1-T*…C4-T*) go into a new file, `test/contract.bats`, owned by U5. It `load`s `helpers.bash` read-only. `test/turso-latency-checker.bats` holds only the A, A2 and B tests (U2) and is never edited in phase 2.
  - **Unsets.** `setup` also unsets `CLAUDECODE`. The suite may itself run inside Claude Code, where that variable is set, and B10 would then silently turn off the animation that B4-T3 and B10-T1 assert.
  - **New helpers U2 lands in phase 1** (U5 cannot edit `helpers.bash`), about 15 LOC:
    - `run_cli_1x`: `TURSO_LATENCY_COMPAT_TABLE=1 run_cli "$@"`. It is a no-op in 1.2.0. In 2.0.0 it restores the 1.x stdout, so B1-T1/T2/T3, B2-T1, B3-T1, B3-T2, B4-T4, B6-T1, B6-T2, B8-T1 and B11-T1 use it and stay green through C1. They then double as the compat switch's contract tests (R402).
    - `run_tty_cols <n>` and `strip_ansi`, for B9.
    - `assert_one_json_line <text>`: exactly one line that parses with `jq -e .`.
    - `parse_only <args…>`: in a subshell, source the script and run `parse_args`, for A-T11 and C3-T7.
  - **No failure exit codes in this file.** Phase-1 tests assert no failure-path exit code; C2's tests in `test/contract.bats` own them. That keeps this file valid in phase 2 with no edits.
- **Round 2 re-check: the PTY harness.** Measured with `/tmp/cli-bp/tlc-r2/probe/run.sh`, `od -c` and real Homebrew bats; the payload was a small probe script, never this CLI. The round-1 `run_tty` wording does not survive these facts:
  - `script -q /dev/null CMD </dev/null` puts `^D\b\b` at byte 0 of the transcript (10 of 10 runs), and every `\n` arrives as `\r\n`. So the "no `\r`" assertions in B4-T3, B10-T1 and C3-T12 can't pass on a raw transcript, and neither can B12-T1's equality.
  - Run directly from a Claude Code Bash call, stdin is a socket and `script` exits 1 with `tcgetattr/ioctl: Operation not supported on socket`. Under real bats it ran with or without a redirect, so `</dev/null` makes both cases the same.
  - **`run_tty`** is therefore `run script -q /dev/null "$TLC_BASH" "$SCRIPT" "$@" </dev/null`, then `output=$(printf '%s' "$output" | LC_ALL=C sed -e $'s/\\^D\b\b//g' -e $'s/\r$//')`, then re-splitting `lines`. Spinner `\r` bytes survive, because they aren't line-final (measured with `od -c`). `run_tty_cols` uses the same wrapper.
  - **B10-T1's stdin-piped mode** keeps `</dev/null` on `script` as well as inside the command.
  - **`setup`** exports `TERM=xterm-256color`. `RICH_*` depend on it, and a session with `TERM` unset or `dumb` would turn off the animation B4-T3 asserts. B4-T1 overrides it per run.
- **Round 2 re-check: stub knobs (B13).** `STUB_CURL_HTTP="bog:503"` and `STUB_CURL_HTTP_ALL=503` set the status the stub prints for `%{http_code}` (default 200). A failed exit prints `000`. U2 lands both in phase 1, because U5 can't edit the stub. B13-T1, B13-T2 and B16-T1 use `run_cli_1x`, so they stay green through C1.

### Files `README.md`, `package.json`, `CHANGELOG.md` (owner U3): BLOCKED until D4

All line numbers below are for the dirty working copy, which D4 is expected to commit.

| Change | Rule | Site |
|---|---|---|
| `Shows a nice spinner animation during testing` → `Shows a progress spinner when run in an interactive terminal` | R226 (soft) | README.md:11 |
| `Simply run the script:` → `Run the script:` | R226 | README.md:64 |
| Usage section gains Options (`-h`, `-v`, `--no-color`, `--timeout`), "Output" (stdout = table; stderr = progress), and the env vars `NO_COLOR`, `FORCE_COLOR`, `TURSO_LATENCY_ACCESSIBLE` | R023 R330 | README.md:62-74 |
| Requirements: drop `bc`; state `Bash 3.2 or later`, `curl` | finding 1 | README.md:76-80 |
| `"version": "1.2.0"` (same PR as the script's `VERSION=1.2.0`) | R022 | package.json:3 |
| delete `"main"` (a shell script cannot be required) | finding 14 | package.json:5 |
| add `"os": ["darwin", "linux"]` (the npm cmd shim cannot run a bash bin on Windows); no `engines` (the bin does not use node) | R390-adjacent | package.json (new key) |
| `"test": "bats test"` | R390 R391 | package.json:13 |
| New `CHANGELOG.md`: a 1.2.0 entry naming unknown-argument exit 2, progress on stderr, dead regions now listed as failed, the bc requirement dropped, and the new options | R022 | new file |
| (Round 2) New "Glossary" section:<br>- **region**: a Turso region; its identity is the 3-letter code, e.g. `ams`.<br>- **location**: the city and country a region serves; display only, never an identity.<br>- **gateway region**.<br>- **probe**: one HTTP GET to a region.<br>Banned synonyms: "location" for a region, and "test" for a probe | R423 R424 | README.md (new section) |
| (Round 2) `identify the fastest location for your connection` → `identify the fastest region for your connection` | R423 | README.md:3, package.json:4 |
| (Round 2) Usage section adds `--non-interactive`, and states that `CI` or `CLAUDECODE` turns animation off (output stays human) | R023 R080 R117 | README.md:62-74 |
| (Round 2) Every `turso-latency-checker …` line in README code blocks must parse: A-T11 reads README.md, so a README example that the parser rejects turns the suite red | R100 | README.md (all examples) |
| (Round 2 re-check) The Options list adds `-d, --debug`. The environment section states that `1` turns `TURSO_LATENCY_ACCESSIBLE` on, that empty means unset, that any other value is a usage error, that options win over variables, and that nothing is saved between runs. Per D9, the Output section also states whether a 5xx or 429 reply counts as a failed region | R023 R079 R080 | README.md:62-74 |

Gate for U3: `jq -e '.version == "1.2.0" and (has("main")|not) and .os == ["darwin","linux"]' package.json`, plus A-T3 un-skipped and green.

---

## 4. Wave C: contract-changing fixes (release 2.0.0)

Under the guide's "Change contracts deliberately" table, a stream or exit-code change needs a major version, release notes naming the replacement, and a deprecation path where feasible.

Callers for every item: none programmatic. The verified census used grep/rg over the repo, `~/Development`, `~/.zshrc`, `~/.bashrc`, `~/bin` and `~/.claude/settings.json`, and found only README usage lines, the npm bin mapping, prose mentions in `chris-resume/evidence/08-npm-renchris.md:10,32,34,40` and `…/A5-chris-exposure.md:79`, and the byte-identical `~/bin` copy. The unknowns are the public npm consumers of 1.1.0. So nothing needs migrating in-tree; the migration is release notes plus the compat switch below.

**C1. Piped stdout becomes a clean result; receipts and failures move to stderr** (findings 3 and 9; R016 R173 R177 R189 R186 R205 R209 R231). **Needs D1.**

- Rows (`print_row`) and header: when `TTY_OUT` is unset, print `outf 'ID\tLocation\tLatency\tGateway\n'`, then `outf '%s\t%s\t%sms\t%s\n' "$loc" "$name" "$ms" "$yesno"`. That means no padding, no rules, no styling (R209) and `yes`/`no` words. On a TTY, the padded table keeps `✓` and gets a Title Case header (`ID  Location  Latency  Gateway`).
- Failure block, `Fastest region:` line and total-failure message: `outf` → `errf` in every mode. On a TTY there is no visible change.
- Compat: `TURSO_LATENCY_COMPAT_TABLE=1` restores the exact 1.2.0 stdout layout for 2.x: padded table, uppercase header, failure block and fastest line on stdout. When set, the script prints once to stderr: `Warning: TURSO_LATENCY_COMPAT_TABLE restores the 1.x output and will be removed in 3.0.0.` This uses the guide's `<PREFIX>_COMPAT_<NAME>=1`, not the verifier's `--format=table`, which would add a second format option next to `--json` (R009, R114).
- Callers: none in-tree. Migration: 2.0.0 release notes plus the README "Output" section. The old behavior stays available behind the compat env var for one major version.

Tests:

| Test name | Assertion |
|---|---|
| `C1-T1 piped stdout is TSV with a Title Case header` | `lines[0] == $'ID\tLocation\tLatency\tGateway'`; every stdout line has exactly 3 tabs (`awk -F'\t' 'NF!=4{exit 1}'`); no run of 2+ spaces; the ams row matches `^ams\tAmsterdam, Netherlands\t[0-9]+ms\tyes$`; stdout has no `Fastest region` and no `Couldn't reach` |
| `C1-T2 receipts and failures are on stderr` | `STUB_CURL_FAIL="bog:28"`, `STUB_CURL_TIMES="ams:0.010"`. stderr contains `Fastest region: ams (Amsterdam, Netherlands) - 10ms (Gateway Region)` and `- bog (Bogotá, Colombia): timed out after 3s` (Round 2: per the C1 addendum, the stderr row is the detail row `  bog (Bogotá, Colombia): timed out after 3s; retried once`, and `Fastest region:` comes before `Measured 34 of 35 regions. 1 failed.`. Round 2 re-check: per C1 addendum 2 that line now reads `Fastest region is ams (Amsterdam, Netherlands) at 10ms (gateway region).`) |
| `C1-T3 TURSO_LATENCY_COMPAT_TABLE=1 restores the 1.x stdout` | stdout `lines[0]` matches `^ID +LOCATION +LATENCY +GATEWAY$`; stdout contains `Fastest region:`; stderr contains the `Warning: TURSO_LATENCY_COMPAT_TABLE` line exactly once |
| `C1-T4 tty table keeps padding and the gateway glyph` | under `run_tty`: an ams row with `✓`, and the Title Case header |

**C1 addendum (Round 2)** (R192 R276 R282 R307 R308 R205 R428 R423 R309). Part of D1, as the D1 addendum describes.

- **The stderr partial-failure report.** After C1 the failure list is a receipt or error on stderr rather than the result, so R192's cap applies to it. That cap did not apply in Wave B, where the list was the stdout result.
  - **Order.** The B6 completion line moves from "after the wait" to after the results, so it is printed once and stderr reads in order: `Fastest region: …`, then `Measured 35 regions.` (success) or the partial report.
  - **Headline.** `<GLYPH_ERR> Measured 33 of 35 regions. 2 failed.` (Reference J Partial). With D2 = 0 it is a plain receipt line with no glyph or prefix.
  - **Detail rows.** One per failed region, indented 2 spaces (R282): `  bog (Bogotá, Colombia): timed out after 3s; retried once`. At most 5, then `  and <N> more`.
  - **Recovery.** A blank line, `See every failed region:` and `    turso-latency-checker --json`. That is the command that lists them all; C3 ships in the same 2.0.0 release.
  - **No heading line.** B6's `Couldn't reach <n> regions via region.turso.io:8080` heading is not printed on stderr: the headline carries the count, and the B3 context line already names the host (R292).
  - **Compat.** `TURSO_LATENCY_COMPAT_TABLE=1` restores the full, uncapped 1.2.0 block on stdout. Stderr then keeps only the headline line, with no detail rows or recovery, so the rows are never printed twice.
- **Compat warning copy (R307, R308, R205).** `Warning: TURSO_LATENCY_COMPAT_TABLE is deprecated and will be removed in 3.0.0. Read the tab-separated output or use --json instead.`
  - On a rich stderr the prefix is the `!` gutter glyph instead of `Warning:`.
  - It prints once per run, before the work starts. Its reason is `deprecated` (Reference K).
  - With `--json` the variable has no effect, and nothing is printed (R309, R244).
- **Header noun (R428, R423; a D1 sub-choice).** Recommended: `Region\tLocation\tLatency\tGateway` (TSV) and `Region  Location  Latency  Gateway` (TTY), because the column holds the region's identity and the glossary calls it a region. If D1 keeps `ID`, C1-T1 and C1-T4 stay as written; otherwise U5 writes them with `Region`.

| Test name | Assertion |
|---|---|
| `C1-T5 stderr failure report caps at 5 rows (R192)` | `STUB_CURL_FAIL="bog:28 gru:7 qro:6 scl:56 eze:7 gig:7 gdl:7"`. stderr has exactly 5 lines matching `^  [a-z]{3} \(`, then `  and 2 more`, an empty line, `See every failed region:` and `    turso-latency-checker --json`. stdout has 28 data rows. With `TURSO_LATENCY_COMPAT_TABLE=1`, stdout lists all 7 failed regions |
| `C1-T6 compat warning names its replacement, once, and never under --json (R308, R309)` | `TURSO_LATENCY_COMPAT_TABLE=1`: exactly one stderr line starts `Warning: TURSO_LATENCY_COMPAT_TABLE is deprecated`, and it contains `--json`. With `--json` added, stderr is empty and stdout is one JSON document; this half of the test lands with C3 |

**C1 addendum 2 (Round 2 re-check)** (R103 R053 R079 R074 R183 R181 R205). Part of D1.

- **The recovery keeps a supplied timeout (R103).** `See every failed region:` reruns the probes, so dropping `--timeout 10s` would rerun at the 3 s default and can report different failures. When the user passed `--timeout`, the recovery is `    turso-latency-checker --json --timeout 10s`, with the value as typed. `set_timeout` has already validated it, so it needs no quoting.
- **The fastest-region receipt (R183, R205, R181; D1 addendum (c)).** Once the line leaves the 1.x stdout contract, it follows the stderr layout.
  - **Plain.** `Fastest region is ams (Amsterdam, Netherlands) at 10ms (gateway region).` (72 columns, measured). The parenthetical appears only for a gateway region.
  - **Rich.** `row Fastest 'ams (Amsterdam, Netherlands), 10ms, gateway region'`.
  - **Compat.** `TURSO_LATENCY_COMPAT_TABLE=1` keeps the old `Fastest region:` line on stdout.
- **The compat variable is documented and strict (R079, R074).** The Notes block gains `TURSO_LATENCY_COMPAT_TABLE=1 restores the 1.x table until 3.0.0.` (66 columns, measured). Its values follow B15: `1` is on, empty is unset, and anything else is a usage error, which is one JSON error document under `--json`.
- **`--json` dependency (R053).** The recovery and the compat warning both name `--json`, which lands in C3. Both ship in the one 2.0.0 release, so no user sees one without the other. D3 covers the case where `--json` is declined.

| Test name | Assertion |
|---|---|
| `C1-T7 the recovery keeps a supplied --timeout (R103, R100)` | `--timeout 10s`, `STUB_CURL_FAIL="bog:28"`: stderr contains `    turso-latency-checker --json --timeout 10s`. With no `--timeout`, it contains `    turso-latency-checker --json`. This half lands with C3: `parse_only --json --timeout 10s` leaves `USAGE_ERR` empty and runs no probes |
| `C1-T8 the compat variable is strict and documented (R074, R079)` | `TURSO_LATENCY_COMPAT_TABLE=yes`: status 2; stderr has `Can't use TURSO_LATENCY_COMPAT_TABLE=yes. Use 1, or leave it empty.`; no probes. `TURSO_LATENCY_COMPAT_TABLE=`: stdout `lines[0]` is the TSV header. `--help` stdout contains `TURSO_LATENCY_COMPAT_TABLE=1` |

**C2. Exit codes report the outcome** (finding 4, plus the exit parts of 1 and 11; R003 R194 R318 R337 R339 R004 R280). **Needs D2.**

- After classification, when `OK_ROWS` is empty, print nothing on stdout and run `die 1 network_error "Couldn't reach region.turso.io:8080 from any region. <Cause>." "Check connectivity to the gateway" "curl --verbose http://region.turso.io:8080/"`.
  - `<Cause>` is the shared cause if every region failed the same way (e.g. `Timed out after 3s`; Round 2: `Timed out after 3 s`, since R214 spaces durations in sentences and keeps them compact only in tables and status rows). Otherwise it is `<k> of 35 probes timed out` for the most common class.
  - This replaces `:211-213`.
  - On this path, skip the B6 `Measured 0 of 35 regions.` line. The guide says that when every item fails in one class, that class's headline is used instead of the Partial one.
- When `FAILED` is non-empty, the B6 line `Measured N of 35 regions. M failed.` is already on stderr. Then `exit 1`. That is R318 and the guide's Partial class, `partial_failure`, exit 1. **D2 alternative:** `exit 0` for a partial result, documented in help and README.
- Otherwise `exit 0`.
- Help Notes gains: `Exits 0 when every region was measured, 1 when any region failed, 2 on a usage error.` The second clause depends on D2.
- Callers: none in-tree. Migration: 2.0.0 plus release notes. No compat switch: an exit-code switch is not one of the guide's stream/format compat uses, and restoring "exit 0 on total failure" would re-create an R339 violation.

Tests:

| Test name | Assertion |
|---|---|
| `C2-T1 all regions fail: exit 1, network error on stderr, empty stdout` | `STUB_CURL_FAIL_ALL=28`. Status 1; stdout empty. The last 4 stderr lines are `Error: Couldn't reach region.turso.io:8080 from any region. Timed out after 3s.`, an empty line, `Check connectivity to the gateway:` and `    curl --verbose http://region.turso.io:8080/`. stderr has no `Measured 0 of`. (Round 2, superseding the line list above: the last 5 stderr lines are `Error: Couldn't reach region.turso.io:8080 from any region. Timed out after 3 s.`, `  Retries         1 per region`, an empty line, `Check connectivity to the gateway:` and `    curl --verbose http://region.turso.io:8080/`. The line before the headline is empty (R282).) |
| `C2-T2 partial failure exit code follows D2` | `STUB_CURL_FAIL="bog:28 gru:7"`. Status 1 (or 0 if D2 says so); stdout has 33 data rows; stderr has `Measured 33 of 35 regions. 2 failed.` |
| `C2-T3 full success exits 0` | status 0; stderr ends with `Measured 35 regions.` |

**C2 addendum (Round 2)** (R214 R282 R316 R276 R181)

- **Sentence durations are spaced (R214).** The headline cause is `Timed out after 3 s.`, and the C3 JSON `message` strings use the same spacing. Table cells and failure rows keep the compact `42ms`/`3s`, because they are status rows.
- **Blank line before the error (R282).** It comes from A2's `ERR_DIRTY` rule; the B3 context line is always on stderr before this error.
- **Retries row (R316, R276).** When the probes were retried, the error adds one detail row after the headline: `  Retries         1 per region`. The label is padded to the 16-column label width, so the value starts at column 18 (R181).
- **Partial failures.** They use C1's stderr partial report, not this Network-class layout.

| Test name | Assertion |
|---|---|
| `C2-T4 a non-transient total failure has no Retries row` | `STUB_CURL_FAIL_ALL=3` (not retried). Status 1; stderr has no `Retries` line. The headline starts with `Error: Couldn't reach region.turso.io:8080 from any region.`; no stderr line contains `(s)` (R217) |

**C2 addendum 2 (Round 2 re-check)** (R099 R284 R283 R291 R299 R103). The HTTP rows need D9.

- **Long options in printed commands (R099).** The gateway recovery is `curl --verbose http://region.turso.io:8080/`, corrected in place in C2, C2-T1 and C3. A-T16 guards it.
- **A total failure in one HTTP class uses that class (R284; Reference J's Partial row).**
  - **Every failure is 5xx or 000.** `die 1 api_error "Failed to measure latency via region.turso.io:8080. The gateway returned server errors."` (87 columns, measured), then `row Status <most common code>`, then the existing recovery. The status stays out of the headline (R283).
  - **Every failure is 429.** `die 1 rate_limited "Too many requests to region.turso.io:8080."`, with the recovery `Run it again later:` and `    turso-latency-checker`, plus any supplied `--timeout` (R103). Reference J's `Try again in <time>` needs a known time, and the probe reads no `Retry-After` (R275).
  - **Mixed classes.** They keep the Network form above.
  - **No `Retries` row.** B13b doesn't retry replies.

| Test name | Assertion |
|---|---|
| `C2-T5 a total failure in one HTTP class uses that class (needs D9)` | `STUB_CURL_HTTP_ALL=503`: status 1; stdout empty; the headline is `Error: Failed to measure latency via region.turso.io:8080. The gateway returned server errors.`; stderr has `  Status          503`. `STUB_CURL_HTTP_ALL=429`: status 1; the headline is `Error: Too many requests to region.turso.io:8080.`; the last stderr line is `    turso-latency-checker` |

**C3. `--json` (additive, but sequenced after C2)** (finding 10; R243 R248 R250 R251 R253 R114 R086). **Needs D3.**

- Why after C2: R006 requires the same exit code in every mode, so `--json` must not ship with exit semantics that default mode does not yet have.
- Parser arm `--json) OPT_JSON=1 ;;`. Help gains `--json  Output the result as JSON` and the example `turso-latency-checker --json`. `resolve_modes` turns `ANIMATE` off, `errf` becomes a no-op, and `die` gains the JSON branch.
- Document (one per run). It is compact when stdout is not a TTY and 2-space pretty on a TTY. Emit it from a fixed template with `NL`/`IND` variables, with no jq dependency.

  ```
  {"regions":[{"id":"ams","location":"Amsterdam, Netherlands","latencyMs":42,"gateway":true,"error":null},
              {"id":"bog","location":"Bogotá, Colombia","latencyMs":null,"gateway":false,
               "error":{"reason":"timeout","message":"Timed out after 3 s.","curlExit":28}}],
   "fastest":{"id":"ams","location":"Amsterdam, Netherlands","latencyMs":42} | null,
   "summary":{"succeeded":34,"failed":1,"skipped":0,"unknown":0},
   "pagination":{"next":null}}
  ```
  (Round 2: `summary` carries all four R248 keys. `skipped` and `unknown` are always 0, but the document reuses the bulk `summary` key, so it keeps the bulk shape. The `message` duration is spaced, per R214.)
  - Order: successes by latency, then failures in `LOCATIONS` order.
  - `error.reason`: `timeout` for rc 28 and for a missing result (`curlExit: null`), `network_error` for anything else.
  - `json_str` escapes `\` and `"`, and the curl stderr text is passed through `tr -d '\000-\037'`.
- Partial result: the full document on stdout, no error document, exit per D2 (guide: a bulk read writes its partial result).
- Total failure: stdout empty. stderr gets one line, `{"status":"error","reason":"network_error","message":"Couldn't reach region.turso.io:8080 from any region. Timed out after 3 s.","next":[{"command":"curl --verbose http://region.turso.io:8080/","argv":["curl","--verbose","http://region.turso.io:8080/"]}],"retryable":true}`, and the script exits 1.
- Usage errors with `--json` anywhere in argv produce a one-line error document with `reason` `unknown_option`/`unknown_command`/`invalid_arguments`, `next` = `turso-latency-checker --help`, and exit 2.
- `--version --json` prints `{"version":"2.0.0"}`.
- SIGINT with `--json` prints one error document with `reason":"canceled"` and exits 130.
- Callers: none (a new flag). Migration: none. It needs D3 only because the shape becomes a contract once it ships.

Tests:

| Test name | Assertion |
|---|---|
| `C3-T1 --json: one compact document on stdout, nothing on stderr` | `echo "$output" \| jq -e '(.regions\|length)==35 and .pagination.next==null and .fastest.id=="ams" and .summary=={"succeeded":35,"failed":0,"skipped":0,"unknown":0}'` (Round 2: four keys); `${#lines[@]} -eq 1`; stderr empty; no `$'\033'` even with `FORCE_COLOR=1` (R209) |
| `C3-T2 --json: failed regions keep latencyMs null and an error reason` | `STUB_CURL_FAIL="bog:28 gru:7"`. `jq -e '.regions[]\|select(.id=="bog")\|.latencyMs==null and .error.reason=="timeout"'`; gru has reason `network_error`; status per D2 |
| `C3-T3 --json total failure: empty stdout, one-line error document, exit 1` | `STUB_CURL_FAIL_ALL=7`. Status 1; stdout empty; stderr is 1 line; `jq -e '.status=="error" and .reason=="network_error" and .next[0].argv[0]=="curl"'` |
| `C3-T4 --json usage error is a JSON error document with exit 2` | `--json --bogus`: status 2; `jq -e '.reason=="unknown_option"'` on stderr; no probes |
| `C3-T5 --version --json prints a version object` | `jq -e '.version\|test("^[0-9]+\\.[0-9]+\\.[0-9]+$")'` |
| `C3-T6 --json on a TTY is pretty-printed` | under `run_tty`, the transcript contains `$'\n  "regions": ['` |

**C3 addendum (Round 2)** (R254 R255 R414 R258 R302 R262 R336 R071 R068 R309 R100 R403). Same commit as C3, owner U4; tests in `test/contract.bats` (U5).

- **`status` by class (R254).**
  - `action_required` for failures blocked before any probe that corrected input or a human step would let run: `unknown_option`, `unknown_command`, `invalid_arguments`, `missing_dependency`, `temp_dir_unavailable`.
  - `error` for `network_error` (probes ran) and `canceled`.
  - The class still sets the exit code (R260).
- **One reason registry (R255, R414).** One `REASONS` block in the helper section lists every reason with its exit code: `unknown_option 2`, `unknown_command 2`, `invalid_arguments 2`, `missing_dependency 1`, `temp_dir_unavailable 1`, `network_error 1`, `partial_failure 1`, `canceled 130`. Per-region `timeout` and `network_error` appear only inside `regions[].error`, and the `deprecated` warning reason comes from Reference K. `die` takes its reason from this block only.
- **Usage error documents (R258, R302, R257).** They carry `data.issues: [{"field","reason","message"}]` with every problem A2 collected, plus `next: [{"command":"turso-latency-checker --help","argv":["turso-latency-checker","--help"]}]`.
- **Signals (R262, R336).** With `--json`, SIGINT (130), SIGTERM (143) and SIGHUP (129) each write one stderr line: `{"status":"error","reason":"canceled","message":"Canceled.","data":{"remote":"none"}}`. `remote` is `none` because the probes are reads whose curl processes are stopped, so no remote work continues. Round 1 covered SIGINT only.
- **Encoding (R071).** `json_str` escapes `\`, `"` and every control character below U+0020 as `\u00XX`. Every string goes through it, including argv-derived text such as a bad `--timeout` value. Round 1 escaped only `\` and `"`.
- **Booleans (R068).** `--json=true` and `--json=false` parse per A2.
- **Compat and JSON (R309).** `TURSO_LATENCY_COMPAT_TABLE` has no effect with `--json`; see the C1 addendum.

| Test name | Assertion |
|---|---|
| `C3-T7 the --json help example parses without running (R100)` | `run_cli --help` has the line `    turso-latency-checker --json` under `Examples:`. `parse_only --json` leaves `USAGE_ERR` empty and sets `OPT_JSON`; no probes. A-T11 covers it too, without being edited |
| `C3-T8 signals under --json write one canceled document` | SIGTERM → status 143, stderr is one line, `jq -e '.status=="error" and .reason=="canceled" and .data.remote=="none"'`. The same for SIGHUP (129), and for SIGINT (130) via A-T9's launcher. Stdout is empty in each case |
| `C3-T9 status and issues follow the class` | `--json --timeout 0 --jsno` → status 2; `assert_one_json_line "$stderr"`; `jq -e '.status=="action_required" and .reason=="invalid_arguments" and (.data.issues\|length)==2'`. `STUB_CURL_FAIL_ALL=7 --json` → `.status=="error"` |
| `C3-T10 every reason comes from the registry` | static: each `die <n> <reason>` literal in the script appears in the `REASONS` block with the same exit code. Every block entry is used by a `die` call or by the partial-failure exit site (`partial_failure`) |
| `C3-T11 JSON stays valid with hostile input; --json=false is human` | `--json --timeout $'a"b\\c\x01'` → status 2, `assert_one_json_line "$stderr"`. `--json=false` → stdout is the TSV table. `--json=maybe` → status 2 |
| `C3-T12 --json on a TTY never animates (R403 matrix, --json mode)` | under `run_tty --json`, and under `run_tty --json --non-interactive=false` (Round 2 re-check, R117): no `\r` and no Braille frame. The status equals `run_cli --json`'s status for the same stub settings (success, and `STUB_CURL_FAIL_ALL=7`) |

**C3 addendum 2 (Round 2 re-check)** (R250 R246 R255 R244 R253 R261 R264). The HTTP rows need D9. Part of D3's shape.

- **`regions[].error` gains `httpStatus` (R250, R246).** It is an integer for an HTTP-class failure, otherwise `null`, and never omitted. For example `{"reason":"api_error","message":"HTTP 503","curlExit":0,"httpStatus":503}` and `{"reason":"timeout","message":"Timed out after 3 s.","curlExit":28,"httpStatus":null}`. C4's `resultSchema.fields` lists `regions[].error.httpStatus` with type `integer|null`.
- **Reasons (R255, R264).** `error.reason` comes from `cause_for` (B13), and `REASONS` gains `api_error 1` and `rate_limited 1`. C2 addendum 2's two new `die` calls use them.
- **`--debug` under `--json` (R244, R253, R261).** Debug lines go to stderr before any error document.

| Test name | Assertion |
|---|---|
| `C3-T13 --json carries the HTTP status (needs D9)` | `STUB_CURL_HTTP="bog:503 gru:429" STUB_CURL_FAIL="arn:7"`, `--json`: `jq -e '.regions[]\|select(.id=="bog")\|.latencyMs==null and .error.reason=="api_error" and .error.httpStatus==503 and .error.curlExit==0'`. gru has reason `rate_limited`, and arn has `.error.httpStatus==null`. `STUB_CURL_HTTP_ALL=503 --json`: status 1, stdout empty, `assert_one_json_line "$stderr"`, `.reason=="api_error"` |
| `C3-T14 --debug under --json keeps stdout clean and the error document last (R244, R261)` | `--json --debug`: stdout is one JSON line, and every stderr line starts with `debug: `. With `STUB_CURL_FAIL_ALL=7` added: stdout empty, the last stderr line parses as JSON with `.reason=="network_error"`, and the 35 lines before it start with `debug: ` |

**C4. Machine-readable help, help search and `--fields`** (Round 2; R106 R107 R108 R252 R454 R087 R069 R070 R061 R195). Additive. **Needs D6.** The JSON parts also need D3. Owner U4; tests in `test/contract.bats` (U5).

- **Why.** R106: "a new `--json` command must declare" a `--help --json` document with a result schema. R252/R454: commands with a result schema accept `--fields`. R107/R108 are MUSTs for every CLI, and round 1 scoped none of them.
- **`--help --json`.** Also `-h --json` and `help --json`. It prints one document on stdout (compact when piped, 2-space pretty on a TTY, R251), exits 0 and runs no probes:
  `{"path":"turso-latency-checker","summary":"Measure latency to every Turso region and show the fastest","subcommands":[],"arguments":[],"options":[{"name":"--fields","short":null,"type":"string","valueHint":"<FIELDS>","default":null,"acceptedValues":["id","location","latencyMs","gateway","error"],"repeat":"last_wins","deprecated":false}, …],"lifecycle":null,"resultSchema":{"fields":[{"path":"regions[].id","type":"string"},{"path":"regions[].latencyMs","type":"integer|null"},…],"secret":[]}}`.
  - Every option entry renders from A2's `OPTS` records, the same ones `usage` prints (R107 "same metadata").
  - With `--json` present, `--help` wins as human help would (R083); it simply renders this document.
- **`help --all --json`.** Prints `{"commands":[<the document above>]}`. `help --all` without `--json` prints the root help, which covers the only command.
- **`help search <TEXT>` (R108).**
  - **Matching.** Case-insensitive substring match over the summary, the glossary nouns (region, location, latency, gateway, probe) and the example lines.
  - **Match.** Prints `turso-latency-checker  Measure latency to every Turso region and show the fastest` on stdout, exit 0.
  - **No match.** Prints `No commands match "<query>"` on stderr (R195: empty-state prose goes to stderr) and exits 0.
  - **With `--json`.** `{"commands":[{"path":"turso-latency-checker","summary":"…"}]}`, or `{"commands":[]}` with nothing on stderr.
  - **Missing query.** A usage error (`invalid_arguments`, exit 2).
  - **Privacy.** The query is never written anywhere else.
  - **Globals at depth.** Global options parse after `help search <TEXT>` (R061).
- **`--fields <FIELDS>` (R252, R454, R069, R070).**
  - **Effect.** A comma-separated list of region keys. Each `regions[]` object keeps only those keys, in canonical order. `fastest`, `summary` and `pagination` are unchanged.
  - **Errors, all exit 2 with no probes.**
    - Unknown field: `Unknown field <f> for --fields.` with the detail row `  Valid fields: id, location, latencyMs, gateway, error.`, reason `invalid_arguments`. In JSON, `data.issues` plus `data.validFields`.
    - An empty value is a usage error.
    - Without `--json`: `Can't use --fields without --json.` (R070 conflict, before any probe).
  - **Repeats.** Last wins.
  - **Help row.** `      --fields <FIELDS>     Region fields to include with --json (default: all)` (79 columns, measured), second in the Options list, after B16's `-d, --debug`.
- **No new example.** The three examples already cover the distinct jobs (R091).
- **Callers and migration.** None; the additions are additive.

| Test name | Assertion |
|---|---|
| `C4-T1 --help --json is one document from the help metadata (R106, R107)` | `jq -e '.path=="turso-latency-checker" and ([.options[].name]==["--debug","--fields","--help","--json","--no-color","--non-interactive","--timeout","--version"]) and (.resultSchema.fields\|length)>0'`. The same 8 long names appear in `--help`'s Options section, in the same order. Exit 0, no probes. `--json --bogus --help` prints the same document |
| `C4-T2 help --all --json lists every command` | `jq -e '.commands\|length==1'`, and `.commands[0]` equals the `--help --json` document (`jq -S` compare) |
| `C4-T3 help search finds, misses quietly, and takes globals (R108, R061)` | `help search REGION` → stdout `turso-latency-checker  Measure latency to every Turso region and show the fastest`, exit 0. `help search kubernetes` → stdout empty, stderr `No commands match "kubernetes"`, exit 0. `help search region --json` → `jq -e '.commands[0].path=="turso-latency-checker"'`. `help search kubernetes --json` → `{"commands":[]}` and empty stderr. `help search` → exit 2. `help search region --no-color` → exit 0 |
| `C4-T4 --fields selects region keys; last wins` | `--json --fields id,latencyMs` → `jq -e '[.regions[]\|keys]\|unique==[["id","latencyMs"]]'`. `--json --fields id --fields latencyMs` → keys `["latencyMs"]` |
| `C4-T5 --fields errors are usage errors before any probe` | `--json --fields id,bogus` → status 2, one stderr JSON line with `.reason=="invalid_arguments" and (.data.validFields\|length)==5`. `--fields id` without `--json` → status 2, `Can't use --fields without --json.` `--json --fields=` → status 2. No probes in any case |

**U3 for 2.0.0 (still blocked on D4):**
- package.json:3 becomes `2.0.0`.
- CHANGELOG 2.0.0 names: piped stdout is TSV; receipts and failures are on stderr; `TURSO_LATENCY_COMPAT_TABLE=1` until 3.0.0; exit 1 on total failure (and on partial, per D2); `--json` and its shape.
- README gains an "Exit codes" table and a `--json` example.
- (Round 2) README and CHANGELOG 2.0.0 also cover:
  - C4's `--fields <FIELDS>`, `--help --json`, `help --all --json` and `help search <TEXT>`;
  - the `Region` header, if D1 picks it;
  - the capped stderr failure report and its `turso-latency-checker --json` follow-up;
  - the compat warning's replacement wording;
  - (Round 2 re-check) the `TURSO_LATENCY_COMPAT_TABLE` value rules, the `Fastest region is …` receipt and the per-region `httpStatus` key.
  
  Every README example stays parseable (A-T11).

### Operator decisions

- **D1 (C1).** Approve the piped-stdout contract change: the TSV layout, `yes`/`no` gateway words and Title Case header, with receipts and failures moved to stderr. Also approve the compat switch name `TURSO_LATENCY_COMPAT_TABLE` and shipping it as 2.0.0. If declined, C1 is dropped and the 1.x piped layout stays. R189 and R016 then remain open for piped runs.
- **D2 (C2).** The partial-failure exit code. **1** follows R318 and the guide's Partial class (recommended). **0** treats unreachable regions as survey data and must be documented as an exception. Total failure exits 1 either way.
- **D3 (C3).** Approve the `--json` document shape above before it ships. After that it is a contract (R243).
  - **Round 2 re-check: the shape includes C3 addendum 2's `httpStatus`.**
  - **Round 2 re-check: if D3 is declined while D1 is approved (R053, R422).** C1's recovery and compat warning would name an option that doesn't exist. So the stderr report lists every failed region with no recovery, recorded as an R192 exception, and the warning ends `Read the tab-separated output instead.` U5 writes C1-T5, C1-T6 and C1-T7 to match, and drops C3-T13 and C3-T14.
- **D4 (U3, blocks every README/package.json change).** README.md and package.json have uncommitted edits in the main checkout. HEAD's package.json is empty, and the working copy holds the published 1.1.0 manifest. The operator must commit them, or say which version is canonical, before U3 starts.
- **D5 (after landing).** `npm publish` and refreshing the byte-identical `~/bin/turso-latency-checker`. Both are operator-only actions outside the repo.
- **D1 addendum (Round 2).** Approving D1 now also approves two choices:
  - **(a) The header noun.** Recommended: `Region` instead of `ID`, in the TSV and TTY headers (R428: label an ID by what it identifies; R423 glossary). Alternative: keep `ID`.
  - **(b) The capped failure report.** The stderr partial-failure report caps at 5 rows, then `and N more`, then `turso-latency-checker --json` (R192). Alternative: list every failed region on stderr, which breaks R192 once the list is no longer the stdout result.
  - **(c) The fastest-region receipt (Round 2 re-check).** Recommended: on stderr it reads `Fastest region is ams (Amsterdam, Netherlands) at 10ms (gateway region).` on a plain stream, and is a `Fastest` label row on a rich one (R183, R205, R181). Alternative: keep the 1.x `Fastest region: …` text on stderr, recorded as an R183 exception (R422).
  
  If D1 is declined, none of these applies, and the 1.x stdout failure block stays uncapped.
- **D6 (C4, Round 2).** Approve the machine-readable help surface as a contract: the `--help --json` document shape (including `resultSchema`), `help --all --json`, `help search <TEXT>` and `--fields <FIELDS>`.
  - **Option A (recommended).** Ship C4 in 2.0.0 with C3. Once `--json` exists, R106 and R252 require `--help --json` and `--fields`, and R107/R108 are MUSTs for every CLI.
  - **Option B.** If D3 declines `--json`, C4 shrinks to human `help search <TEXT>` and `help --all`, about 20 script LOC (estimated from the C4 sketch).
- **D7 (Wave A exit 2 and B3 stdout cleanup versus R386, Round 2).** R064 and R013 require rejecting unknown arguments, and R016 requires a clean stdout. R386 requires a major version for any exit-code or stream change. The repo documents no contract either way.
  - **Option A (plan default, recommended).** Ship both in 1.2.0. Unknown arguments exit 2 with an error; there is no in-tree caller (the round-1 census), and the failure is loud, not silent. The banner, heading and blank lines leave stdout, and the rows are unchanged (B3-T2).
  - **Option B (strict R386).** In 1.2.0, an unknown argument prints `Warning: Unknown option --x for turso-latency-checker. This will be an error in 2.0.0.` (reason `deprecated`; exit unchanged), and the banner stays on stdout. Both flip in 2.0.0 with C1 and C2. This changes A-T4, A-T5, A-T13 and B3-T1 to their 2.0.0 form in `test/contract.bats`.
- **D8 (implementer split, Round 2).** Scheduling only, not a contract. The script must ship as one file (section 1, Distribution constraint), and its total change is about 644 LOC (estimated, section 6), over the 500 cap. A file-disjoint split is impossible.
  - **Option A (recommended).** U1 owns `turso-latency-checker.sh` for phase 1 (about 409 LOC). U4 owns it for phase 2 (about 235 LOC), starting only from U1's merged commit, so the two never hold the file at the same time.
  - **Option B.** One owner, U1, at about 644 LOC across sessions S2 and S4, above the cap.
- **D9 (B13b, C2 addendum 2, C3 addendum 2; Round 2 re-check).** Does a 5xx or 429 reply mean the probe failed? Static reading can't settle this, because nobody has measured what the gateway replies. Before answering, the operator runs this once. It is an outbound request to the public gateway, so no implementer or test does it:

  ```
  curl -sS -o /dev/null -w '%{http_code}\n' -H 'fly-prefer-region: ams' http://region.turso.io:8080/
  ```

  - **Option A (recommended, if that reply is not 5xx or 429).** Land B13b, so those replies become failed regions and a fast error reply can't win `Fastest region` (R003).
  - **Option B (if the normal reply is 5xx or 429, or the operator wants plain round-trip time).** Drop B13b, B13-T1, B13-T2, C2-T5, C3-T13, `httpStatus` and the two new `REASONS` rows. Keep the `%{http_code}` capture and `cause_for`. Help Notes then adds `Any HTTP reply counts as a measured region.`, and that choice is recorded as an R003 reading (R422).

---

## 5. Dropped (one line each)

- Finding 2's proposed `--json`/`--no-color`/`--timeout` help lines in the parser commit: dropped as R023/R437 violations. Each flag ships with its behavior (A, A, C3).
- Finding 1 "a region with no result file is silently dropped": overstated. Today the spinner hangs instead. Covered by the B2 bounded wait plus missing-equals-failed.
- Finding 5 case (c) "a stale same-PID dir pushes the count past 35": refuted (fixed names cap the count at 35). The real stale-dir bug is fixed by mktemp in Wave A, not by `-ge`.
- Finding 9 R191 truncation (`:155-156`): dead code, since the longest name is 28 characters. The branch is deleted with no behavior change.
- Finding 9's `--format=table` back-compat flag: replaced by the guide's `<PREFIX>_COMPAT_<NAME>` env switch, so `--json` has no second format option (R009/R114).
- Finding 7's refined fix gating the spinner on `NO_COLOR`: rejected under R207 (turning color off removes only color).
- Finding 11's "at most 5 failed rows then `and N more`": dropped. The failed-region list is the result, and R302's cap applies to validation issue lists. (Round 2: this holds only for Wave B's stdout list. After C1 the list is a stderr report, and the C1 addendum caps it under R192.)
- Finding 11's optional "exit 2 on partial failure": dropped. Exit 2 is reserved for usage errors (R337).
- Finding 10's "partial failure exits 0 inside --json": superseded by D2, because modes must share exit codes (R006).
- Finding 12's https switch: dropped (it would change the measured quantity, and port 8080 TLS is unverified). R437 was misapplied and R330 is weak for a one-shot probe. `--connect-timeout` is optional hardening, not planned.
- Finding 13's `=====`/`-----` rules and README `nice`: no cited rule mandates removing them. `=====` goes away with the banner rewrite (B3), `-----` is kept on a TTY only, and `nice` becomes a style edit in U3.
- Finding 14's R023 citation and `engines.node`: dropped. The script has no help to mismatch yet, and the bin does not use node.
- Vercel-specific details not adopted: the `▲` usage glyph, `VERCEL_*` names, team/scope/login classes. Everything adopted here is general CLI practice. The verifier marked no finding as Vercel-specific.
  - **Round 2 correction.** Only the `▲` glyph is actually Vercel-specific: it is on the checklist's "Excluded as Vercel-specific" list, together with the bold-magenta headings. The checklist generalized the other two, and this plan adopts them:
    - `VERCEL_*` became `<PREFIX>_*`, adopted here as `TURSO_LATENCY_ACCESSIBLE` and `TURSO_LATENCY_COMPAT_TABLE`.
    - team/scope became "context", and the Authentication and Permission classes are kept in Reference J. They are **not applicable** because this CLI has no context, auth or token. That is not the same as Vercel-specific.
  - **Not narrowed on that ground.** No rule in this plan is narrowed as "Vercel-specific": `--json` stays the only format selector (no `--format`), exit codes stay 0/1/2/130/128+n, `✗` and `Error:` are used, and `-v` is version.
- **Round 2 re-check: three more items are not adopted, none as "Vercel-specific".**
  - **Reference B's `--cwd`, `-A, --local-config`, `-Q, --global-config`, `-S, --scope` and `-t, --token` (R062).** Not applicable: this CLI has no path input, config, context or token.
  - **R299's request ID.** The probe discards response headers and none has been measured, so there is no known ID to print. Recorded exception (R422).
  - **R295's `internal_error`.** No row. The script has no `set -e` or catch-all, and B1's classification loop turns every unexpected value into a failed region.

---

## 6. Implementation sizing

LOC below are **estimated**: line counts of the code sketches and test tables in this plan, rounded. Nothing was implemented or measured.

**Round 2 update.** The round-1 totals were script ~390, tests ~360, docs ~70, total ~820. The table below adds A2, B8–B12, the C1/C2/C3 addenda and C4. Each added figure is estimated by line-counting that item's sketch and test rows in this plan, rounded.

**Round 2 re-check update.** The table now also adds B13–B16, the second C1, C2 and C3 addenda, A-T16, B9-T3, B10-T3 and the PTY harness: script +62, tests +87, docs +4, total +153 over the ~1318 of the first Round 2 pass (estimated the same way).

| Wave | Script (U1 phase 1 / U4 phase 2) | Tests (U2 phase 1 / U5 phase 2) | Docs/metadata (U3) | Total |
|---|---|---|---|---|
| A: helper block, main wiring, A2 | ~157 (A ~120, A2 ~37) | ~235 (stub ~56, helpers ~62, A-T1..A-T16 ~117) | — | ~392 |
| B: B1–B16 | ~252 (B1–B7 ~160 with ~110 old lines deleted; B8 ~11, B9 ~23, B10 ~8, B11 ~4, B12 ~12, B13 ~12, B14 ~6, B15 ~8, B16 ~8) | ~258 (B1–B7 ~120; B3-T2 ~10, B4-T2 rewrite ~5, B8 ~15, B9 ~24, B10 ~35, B11 ~6, B12 ~10, B13 ~14, B14 ~6, B15 ~6, B16 ~7) | ~53 (1.2.0 docs ~35, glossary and new options ~15, environment rules and `--debug` ~3; after D4) | ~563 |
| C: C1–C4 | ~235 (C1–C3 ~110; addenda ~64; C4 ~61) | ~233 (C1–C3 ~100; addenda ~88; C4 ~45) | ~48 (2.0.0 docs ~35, C4 and D1 addendum ~13; after D4) | ~516 |
| **Total** | **~644** | **~726** | **~101** | **~1471** |

**Implementer units** (Round 2; each under 500 LOC; test and docs units own disjoint files; the two script units share one file serially, see D8):

| Unit | Owns (exclusively, for its phase) | Scope | Est. LOC | Can start |
|---|---|---|---|---|
| U1 | `turso-latency-checker.sh` (phase 1) | Wave A, A2, B1–B16; `VERSION=1.2.0` in the release commit | ~409 | now (B13b after D9) |
| U4 | `turso-latency-checker.sh` (phase 2; serial successor of U1, D8) | C1–C4; `VERSION=2.0.0` in the release commit | ~235 | after U1's PR merges and D1–D3 and D6 are answered |
| U2 | `test/helpers.bash`, `test/fixtures/bin/curl`, `test/fixtures/nobc/bc`, `test/turso-latency-checker.bats` | A, A2 and B tests, plus every helper U5 needs (`run_cli_1x`, `run_tty_cols`, `strip_ansi`, `assert_one_json_line`, `parse_only`), each test red-first ahead of its U1 commit; never edited in phase 2 | ~493 | now, in parallel with U1 (B13-T1 and B13-T2 after D9) |
| U5 | `test/contract.bats` (new) | C1–C4 tests, red-first ahead of each U4 commit; `load`s `helpers.bash` read-only | ~233 | after U2's PR merges and D1–D3 and D6 are answered |
| U3 | `README.md`, `package.json`, `CHANGELOG.md` (new) | 1.2.0 and 2.0.0 docs and metadata, including the glossary | ~101 | only after D4 |

**Round 2 re-check: U2's margin.** U2 at ~493 is under the 500 cap by an estimate's margin. If its count passes 500 during implementation, its B13–B16 tests (~33 LOC) move to a new file, `test/modes.bats`, under a new unit U6 that owns only that file. U2 then falls to ~460, and the units stay file-disjoint. U6 `load`s `helpers.bash` read-only, as U5 does.

Round-1 units for reference: U1 ~390 (script, both phases), U2 ~360 (all tests), U3 ~70. Splitting tests by phase into `test/turso-latency-checker.bats` and `test/contract.bats` keeps U2 and U5 file-disjoint. That works because phase-1 tests use `run_cli_1x` and never assert failure exit codes, so C1 and C2 do not force edits to U2's file.

Order inside phase 1: U2 lands the A tests, then U1 lands A; then for each of B1, B2, B3, B4, B5, B6, B7, U2's red test is followed by U1's fix, and all gates pass after each pair. Phase 2 follows the same pattern for C1, then C2, then C3. U3 lands in the release PR of each phase. (Round 2: phase 1 runs A, A2, B1 … B16, with B13b gated on D9; phase 2 runs C1 → C2 → C3 → C4 with U5's red test before each U4 fix.)

---

## 7. Round 2 changes

**Inputs.**
- **(a) New findings.** The round-2 new-findings input for this repo was empty (`New findings: []`), so no rows came from CLIs not audited in round 1.
- **(b) Critic entries.** Every `/tmp/cli-bp/critic2.json` entry that concerns this repo was checked against HEAD `61cf16b` before any plan change.
- **(c) Sizing and split.** Section 6.

**Re-measured repo facts** (read-only, no CLI executed):
- `git log -1` is still `61cf16b`, and `git status --porcelain` still shows only ` M README.md` and ` M package.json`.
- `git ls-files` lists 3 files, and there is still no `CLAUDE.md`, `.claude/` or `AGENTS.md`. With no repo gates to contradict, the "dropped install step" class of conflict cannot occur here. The working-copy `package.json` has no dependencies and there is no lockfile, so no `node_modules` step exists.
- `cmp` of `~/bin/turso-latency-checker` against the script still prints SAME.

### Critic entries and verdicts

| Critic entry | Verified against | Verdict | Plan change |
|---|---|---|---|
| missedFindings "Plan-level, R100" (this plan's C3 `--json` example has no parser test) | C3 example; Wave A's two examples; printed recovery commands | Confirmed, and wider than reported: Wave A's examples, README examples and the printed `--help` recovery line had no parser test either | A2 makes the script sourceable; A-T11 parses every help example, README example and printed self-command without running; C3-T7 |
| unmentionedRules R100 | same | same | same |
| unmentionedRules R107, R108 ("MUSTs no plan scopes") | parser arms (`help` only as a `--help` alias) | Confirmed missing. R106 and R252 are also triggered once C3 adds `--json` | C4, D6 |
| unmentionedRules R245–R264 (JSON contract details) | C3 rows | Missing: R248 (`summary` lacked `skipped`/`unknown`), R252 (`--fields`), R254 (`status` per class), R255 (registry), R258 (`data.issues`), R262 (SIGTERM/SIGHUP documents, `data.remote`), R071 (control-char escaping). Already met: R250, R251, R253, R257, R259, R260, R261 | C3 addendum, C4; C3 example and C3-T1 corrected |
| unmentionedRules R088/R092/R096/R101/R104 (help content) | Wave A usage text; the Notes paragraph | R088/R096 not applicable (one command, no groups). R101/R104 met. R092 broken: B5's retry contradicts "one plain-HTTP GET". Also found: R095 (the B4 Notes line measures 108 columns), R232 (no Oxford comma), R098 (no rich help styling) | Notes correction block; A-T15; B12 |
| unmentionedRules R112/R117/R119 (mode resolution) | Wave A `ANIMATE` line | Missing: R117 (no agent detection) and R113/R062 (`--non-interactive`). R119 not applicable (no stdin payload) | B10, B10-T1, C3-T12 |
| unmentionedRules R214–R218 ("turso's durations are already compact") | HEAD `:161-175`; this plan's new copy | Confirmed for the 1.x table. But this plan's new copy broke R217 (`Couldn't reach %d regions` prints "1 regions") and R214 (sentence `Timed out after 3s.`) | B8 `plural`; C2 addendum (`3 s` in sentences); C3 strings corrected |
| unmentionedRules R306–R312 (warnings) | C1 compat warning | Missing: R307 (no `!` gutter, no fix), R308 (no replacement named); R309 interplay with `--json` unspecified | C1 addendum, C1-T6 |
| unmentionedRules R316 (retry message) | B5 | `Retrying automatically…` met; the `Retries` detail after an exhausted retry was missing | B11, C2 addendum, C2-T1 corrected |
| unmentionedRules R327/R329 (long-running work) | B2, B4 | R327 met (immediate context line; the spinner names its phase and real total); R329 missing | B8 `Still measuring …` and B8-T3 |
| unmentionedRules R374 (`turso-latency-checker.sh:50` prints `Unknown location`) | HEAD `:7`, `:14-50` | Confirmed as written. Unreachable today: the 35 codes and the 35 case arms are identical (measured with `diff`) | B8 (raw code), B8-T2 |
| unmentionedRules R383–R385 (contract-change process) | A, B3, C1–C3 | Followed in practice. Missing: R384/R402 test that old invocations are unchanged. Open tension with R386: A's exit 2 and B3's stdout cleanup ship in a minor release | B3-T2; D7 |
| unmentionedRules R392/R394/R396–R407 (test obligations) | all test tables | R392/R393 partial. R401 missing, and the fixed 66-column TTY header (6+2+36+2+11+2+7, counted from `:128`) cannot fit 40 columns. R403 missing. R404 met, except the B4-T2 row, which asserted a violation | A-T12; B9 and B9-T1/T2; B10-T1; C3-T12; B4-T2 corrected |
| unmentionedRules R423 (noun glossary) | script strings, README:3, package.json:4 | Missing. "location" is used for a region, and "test" for a probe | B8 lint; U3 glossary rows; D1 addendum (`Region` header per R428) |
| unmentionedRules R020/R165/R293/R300/R315/R317 | `curl` GETs only (`:71`) | Not applicable; agrees with the critic | none |
| unmentionedRules R072, R434–R475 (standard option spellings) | parser arms in this plan | Satisfied or not applicable; agrees with the critic. The plan adds no `--format`, `--confirm`, `-f` or `<CENTS>`, and the new hints are `<DURATION>` and `<FIELDS>` (both on the Reference E list) | none |
| unmentionedRules R174–R176, R265–R272, R343–R346, R367–R389, R109, R110 | — | Not applicable: no mutations or stdout identifiers, no streams, no paging (`pagination.next: null` is kept for the list shape), no update notifier or telemetry, no completion scripts, no lifecycle labels | none |
| planConflicts "rules re-classified as Vercel-specific" | section 5, Dropped | This plan mislabeled `VERCEL_*` names and the team/scope/login classes as Vercel-specific; they are generalized, and not applicable here | Corrected in place; nothing was narrowed on that ground |
| planConflicts "banned spellings" (`--format`, `--confirm`, `<CENTS>`) | whole plan | None occur in this plan | none |
| planConflicts "cc-bats refusal reads as green" (raised for personal.md) | `type -a bats` → `~/.claude/bin/bats` → `cc-bats` | The same trap applies to this plan's bats gates | Gates bullet: assert `1..N`; Phase 0 goals |
| uncoveredClis | `git ls-files`; `cmp` of the `~/bin` copy | None for this repo: one executable, and its deployed copy is byte-identical | none |

### Rows corrected in place (they contradicted the checklist)

- Wave A API `resolve_modes` (R208/R209: only rich streams are styled; forced color on a pipe may tint only `Error:`/`Warning:`).
- The INT trap and A-T9 (R294/R328: clear the spinner, then `Canceled.` and `Nothing was changed.`).
- B4-T2, which asserted bold on a piped stdout.
- B2-T1, which asserted a failure exit code that C2 changes.
- The help Notes paragraph (R095, R232, R092).
- C1-T2 (detail rows and order).
- C2's cause example and C2-T1 (R214 spacing, R316 Retries row, R282 blank line).
- The C3 document example, the total-failure document and C3-T1 (R248 summary keys, R214).
- The Dropped section's Vercel line.
- Phase 0's S3 and S4 rows, roster and dependency graph; the landing-flow commit lists; the sizing and units tables.

### Added

- **Commits.** A2, B8–B12, the C1/C2/C3 addenda and C4.
- **Tests.**
  - A2: A-T11 to A-T15.
  - Wave B: B3-T2, B8-T1 to B8-T4, B9-T1/T2, B10-T1/T2, B11-T1, B12-T1.
  - Wave C: C1-T5/T6, C2-T4, C3-T7 to C3-T12, C4-T1 to C4-T5.
- **Docs.** U3 rows for the glossary, wording, new options and README-example parsing.
- **Decisions.** The D1 addendum, D6, D7 and D8.
- **Process.** The bats `1..N` gate rule; the phase-2 test file `test/contract.bats`; the `CLAUDECODE` unset in `helpers.bash`.

### Help examples and the test that parses each one (R100)

| Printed command | Lands in | Parser test (parse only, never run) |
|---|---|---|
| `turso-latency-checker` (Examples) | A | A-T11 |
| `turso-latency-checker --timeout 10s` (Examples) | A | A-T11 |
| `turso-latency-checker --json` (Examples) | C3 | A-T11 (it does not fix the example count) and C3-T7 |
| `turso-latency-checker --help` (usage-error recovery) | A | A-T11 |
| `turso-latency-checker --json` (C1 failure-report recovery) | C1 | C3-T7 (same argv) |
| every `turso-latency-checker …` line in README code blocks | U3 | A-T11 |
| `turso-latency-checker --json --timeout 10s` (C1 recovery with a supplied timeout; Round 2 re-check) | C1 addendum 2 | C1-T7, via `parse_only` |
| `turso-latency-checker` (rate-limit recovery; Round 2 re-check) | C2 addendum 2 | A-T11 (same argv as the bare example), and C2-T5 pins the text |
| `curl --verbose http://region.turso.io:8080/` (gateway recovery; third-party, so it can't go through this parser) | C2 | A-T16 forbids a short option in it, and C2-T1 pins the text |

C4 adds no example (R091). Its options are covered by C4-T1..T5.

### Sizing after Round 2

All figures are estimated, as in section 6: script ~644 (U1 ~409, U4 ~235), tests ~726 (U2 ~493, U5 ~233), docs ~101 (U3), total ~1471. The first Round 2 pass totaled ~1318, and Round 1's total was ~820. Every unit is under 500 LOC. The test and docs units own disjoint files. The two script units share the one script file serially, because the single-file distribution forces it (D8).

### Round 2 re-check (re-run after a usage-limit interruption)

The amend step was interrupted by a usage limit and re-run on a plan that already held the section above. This pass repeated the repo checks, read every `critic2.json` entry again, and changed only what is listed here. The new-findings input was still `[]`.

**Method and limits.**
- **Repo.** `git log -1`, `git status --porcelain`, `git ls-files` and `cmp` against `~/bin/turso-latency-checker` give the same results as the "Re-measured repo facts" above (measured). There is still no `CLAUDE.md`, `.claude/` or `AGENTS.md`, so there are no repo gates to contradict.
- **Nothing in the repo ran or changed.** The CLI was not executed, and no request reached the gateway. D9 exists because of that.
- **Probes, unlike the earlier pass.** The PTY facts come from harmless child scripts in `/tmp/cli-bp/tlc-r2/probe/`, run through `script(1)` and real Homebrew bats. The `cc-bats` shim was not run, because it is an audited CLI.
- **Not checked.** Whether the gateway can answer from a region other than the one `fly-prefer-region` asks for, which would misattribute a latency. Only a live probe can show that, and it is outside this plan.

**Critic entries the table above had no row for.** Each was checked against HEAD `61cf16b` and this plan's rows.

| Critic entry | Verified against | Verdict | Plan change |
|---|---|---|---|
| unmentionedRules R060 (say "option", not "flag") | every user-facing string in this plan | Met. "flag" appears only in plan prose (measured: `grep -n -i flag`) | none |
| unmentionedRules R179, R180, R183, R184, R190, R193, R196 (transcript layout) | B6, C1 | R183 and R184 broken by this plan's own copy: B6's heading ended in a colon, and `Fastest region:` stays a colon label after it leaves the 1.x stdout contract. The critic raised the same pattern for worktree-harness. The other rules are met or not applicable | B6 heading corrected; C1 addendum 2; D1 addendum (c) |
| unmentionedRules R202 | B12 | Met: B12 styles headings, option names, examples and the summary, and the `Learn more:` URL stays whole and unstyled | none |
| unmentionedRules R212 | B9 | Met: only Location is cut, never an ID, latency, command or URL | none |
| unmentionedRules R221–R225, R228, R229, R233, R234 (writing) | `grep -iE` over this plan and the script for sorry, invalid input, you entered, successfully, Unable to, Are you sure, click here, whitelist, sanity check, dummy; a curly-quote grep | Met: 0 hits in both (measured). One related verb fix: "Can't create a temp directory" describes a failed attempt (R285) | `Couldn't create …` in the Wave A API and B2-T2 |
| unmentionedRules R235, R237–R239, R242 (next steps, tips) | every recovery row | The CLI prints recovery only, with no tip or optional step, so R238 and R239 gate nothing. Related break, R103: C1's recovery dropped a supplied `--timeout` | C1 addendum 2, C1-T7 |
| unmentionedRules R281, R286–R291, R296, R299, R301, R305 (error classes, API mapping) | HEAD `:71`; B1, B5, B6, C2, C3 | The critic named other repos, but R291, R296 and R299 also apply here: the probe is an HTTP client that never reads the status, so a 503 prints as a latency. R281 met. R286–R290, R301 and R305 not applicable | B13, C2 addendum 2, C3 addendum 2, D9 |
| unmentionedRules R320–R324, R326 | `curl` GETs only | Not applicable: no staged work, diff, publish, schedule or mutation | none |
| unmentionedRules R340, R342 | the `cleanup` sketch | Met: no offers, and `cleanup` never calls `exit`, so the exit code survives | none |
| unmentionedRules R470–R473, R476–R478 | output strings; `grep -iE '\b(the\|a\|this) resource\b'` | R471 met: 0 hits (measured). R477 met: `Turso` keeps its case. The rest are not applicable | none |
| unmentionedRules R025–R052, R054–R059, R073, R075–R078, R139–R145 (grammar, extensions, context) | parser arms | Not applicable: a flat CLI with no groups, extensions, config or context. R074 and R079 from that family do apply | B15, C1-T8 |
| unmentionedRules R018, R033, R035, R122–R135, R149–R172, R349, R356–R358, R480 (secrets, verbs, prompts, consent, spending, auth, stdin) | the script has no `read`, secret, charge, login or destructive verb (measured: `grep`) | Not applicable | none |
| unmentionedRules R245, R247, R249, R264 (left open by the row above) | C3 | R245 not applicable (no `--follow`). R247 and R249 met. R264 was at risk, because B6's cause map and C3's reason map were separate | `cause_for` in B13 |

**Plan rows corrected in place (they contradicted the checklist or measured facts).**
- **R099.** `curl -v` in C2, C2-T1 and the C3 document became `curl --verbose`.
- **R113, R117.** B10 made `--non-interactive=false` a no-op under `CLAUDECODE`.
- **R102, R436.** `help search <query>` in the U3 list and D6 became `<TEXT>`, matching C4's hint.
- **R183, R184.** B6, B6-T1, B8, B8-T1 and the C1 addendum: no colon on the heading.
- **R285.** The Wave A API and B2-T2.
- **Red-first.** A-T15 passed at HEAD, so it now also asserts the Usage line. The S1 and S3 goals now name the guards that can't be red (B3-T2, C2-T3, and C2-T2 if D2 = 0); as written, those unattended goals could not be met.
- **B9 width.** `stty size <&1` fails inside `$(…)`, and a PTY width of 0 selected the record layout (measured).
- **`run_tty`.** `^D\b\b` and `\r\n` made the "no `\r`" rows in B4-T3, B10-T1 and C3-T12, and B12-T1's equality, impossible to pass on a raw transcript (measured).
- **Consistency.** C1-T2, C3-T12, C4's help row, C4-T1's option list, the Options order in section 2, the Dropped row for finding 11, D8's sizes, Phase 0's S2 scope and dependency note, and the landing flow's commit list.

**Added.**
- **Commits.** B13 (with B13b), B14, B15 and B16; C1, C2 and C3 addenda 2.
- **Tests.** A-T16, B9-T3, B10-T3, B13-T1 to T3, B14-T1, B15-T1, B16-T1, C1-T7, C1-T8, C2-T5, C3-T13 and C3-T14.
- **Decisions.** D9, D1 addendum (c), and the D3 case where `--json` is declined.
- **Docs.** U3 rows for `--debug` and the environment rules; the U3 2.0.0 list.
- **Harness.** The `run_tty` spec, `TERM` in `setup`, and two stub knobs.
- **Contingency.** U6 and `test/modes.bats`, if U2 passes 500 LOC.

**Compatibility and sizing.** B13–B16 ship in 1.2.0 as compatible changes. B13b's visible change matches B1's: a region moves from the table to the failure list, on the same reasoning as D7's Option A, and D9 lets the operator refuse it. Sizes are in section 6 and "Sizing after Round 2" above. No plan section was removed or rewritten.
