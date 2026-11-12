#!/bin/sh
# Tests for skill/skills/atlas/bin/atlas-usage.sh. No network: fake programs and a local folder
# stand in for the release (ATLAS_USAGE_TEST_SOURCE), and the pins are made here.
#   usage: sh tests/launcher/test-launcher.sh [shell to run the launcher with, default sh]
# Runs on Linux and macOS.

SHELL_UNDER_TEST=${1:-sh}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
launcher_src=$repo/skill/skills/atlas/bin/atlas-usage.sh

T=$(mktemp -d "${TMPDIR:-/tmp}/atlas-launcher-test.XXXXXX")
trap 'rm -rf "$T"' EXIT

passed=0
failed=0
ok() { passed=$((passed + 1)); printf 'ok   %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf 'FAIL %s\n' "$1"; [ -n "$2" ] && printf '     %s\n' "$2"; }
check() { # name condition-command...
  name=$1; shift
  if "$@"; then ok "$name"; else bad "$name" "out: $(head -c 600 "$T/out" 2>/dev/null) | err: $(head -c 600 "$T/err" 2>/dev/null)"; fi
}
has_out() { grep -q -- "$1" "$T/out"; }
has_err() { grep -q -- "$1" "$T/err"; }

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

case $(uname -s) in
  Darwin) asset=atlas-usage-macos-universal ;;
  Linux)
    case $(uname -m) in aarch64 | arm64) asset=atlas-usage-linux-arm64 ;; *) asset=atlas-usage-linux-x64 ;; esac
    for lm in /lib/ld-musl-*.so.1; do [ -e "$lm" ] && asset=$asset-musl; done
    ;;
  *) echo "skip: this test runs on Linux and macOS"; exit 0 ;;
esac

# fake <file> <id> [old]: prints its id and arguments; an "old" one knows no repeats/debrief.
fake() {
  if [ "$3" = old ]; then
    printf '#!/bin/sh\necho "fake %s $*"\n' "$2" >"$1"
  else
    cat >"$1" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "repeats --help") echo "usage: repeats, offer-note"; exit 0 ;;
  "debrief --help") echo "what this chat's helpers did"; exit 0 ;;
esac
[ -n "\$FAKE_LOG" ] && echo run >>"\$FAKE_LOG"
echo "fake $2 \$*"
EOF
  fi
  chmod +x "$1"
}

# A plugin tree at $T/p<n> with the given version; the release folder $T/rel<n>.
setup() { # n version
  P=$T/p$1
  mkdir -p "$P/.claude-plugin" "$P/skills/atlas/bin"
  printf '{ "name": "atlas", "version": "%s" }\n' "$2" >"$P/.claude-plugin/plugin.json"
  cp "$launcher_src" "$P/skills/atlas/bin/atlas-usage.sh"
  printf '# test pins\n' >"$P/skills/atlas/bin/checksums.txt"
  L=$P/skills/atlas/bin/atlas-usage.sh
  PINS=$P/skills/atlas/bin/checksums.txt
  REL=$T/rel$1
  mkdir -p "$REL"
}
pin() { printf '%s %s %s\n' "$1" "$2" "$(sha "$3")" >>"$PINS"; }

# A PATH without any real atlas-usage.
mkdir -p "$T/emptybin" "$T/home"
BASEPATH=$T/emptybin:/usr/bin:/bin:/usr/sbin:/sbin
command -v gh >/dev/null 2>&1 && ln -s /bin/false "$T/emptybin/gh"
run() { # extra env assignments are given through env
  env -i PATH="${RUNPATH:-$BASEPATH}" HOME="$T/home" TMPDIR="$T" CLAUDE_PLUGIN_DATA="${DATA-$T/data}" \
    ATLAS_USAGE_TEST_SOURCE="${SRC-$REL}" ATLAS_USAGE_LAUNCHER_VERBOSE=1 FAKE_LOG="$FAKE_LOG" \
    ${EXTRA:+"$EXTRA"} "$SHELL_UNDER_TEST" "$L" "$@" >"$T/out" 2>"$T/err"
}

# --- 1. first run downloads, checks the pin, saves, runs with the arguments unchanged
setup 1 1.0.0
fake "$REL/$asset" v1
pin 1.0.0 "$asset" "$REL/$asset"
run week --top 3; rc=$?
check "download: exit 0" [ "$rc" = 0 ]
check "download: runs with the same arguments" has_out "fake v1 week --top 3"
check "download: says what it fetched" has_err "downloading the program for"
check "download: reports size" has_err "matches the pinned checksum"
check "download: saved under the plugin data folder" [ -x "$T/data/cache/1.0.0/atlas-usage" ]

# --- 2. second run uses the saved copy
run today; rc=$?
check "cache: used" has_err "launcher: cache:"
check "cache: output" has_out "fake v1 today"

# --- 3. a saved copy that no longer matches its pin is deleted and fetched again
printf '#!/bin/sh\necho tampered\n' >"$T/data/cache/1.0.0/atlas-usage"
run today; rc=$?
check "tampered cache: not run" sh -c "! grep -q tampered '$T/out'"
check "tampered cache: refetched and run" has_out "fake v1 today"
check "tampered cache: says so" has_err "did not match the checksum"

# --- 4. checksum mismatch on download: exit 3, nothing saved
setup 2 2.0.0
fake "$REL/$asset" v2
printf '2.0.0 %s %s\n' "$asset" 0000000000000000000000000000000000000000000000000000000000000000 >>"$PINS"
DATA=$T/data2 run week; rc=$?
check "mismatch: exit 3" [ "$rc" = 3 ]
check "mismatch: message" has_err "did not match the checksum pinned"
check "mismatch: nothing saved" [ ! -e "$T/data2/cache/2.0.0/atlas-usage" ]

# --- 5. no pin for this version: exit 3 and the exact update command
setup 3 3.0.0
fake "$REL/$asset" v3
DATA=$T/data3 run week; rc=$?
check "no pin: exit 3" [ "$rc" = 3 ]
check "no pin: names the update command" has_err "/plugin marketplace update atlas"

# --- 6. a version with pins, but none for this computer
setup 4 4.0.0
fake "$REL/other" v4
pin 4.0.0 atlas-usage-some-other-computer "$REL/other"
DATA=$T/data4 run week; rc=$?
check "no build for this computer: exit 3" [ "$rc" = 3 ]
check "no build for this computer: says so" has_err "no ready-made build for"

# --- 7. offline after a plugin update: the older saved copy answers, with a note
setup 5 1.0.0
fake "$REL/$asset" v1
pin 1.0.0 "$asset" "$REL/$asset"
DATA=$T/data5 run week
check "offline setup: v1 saved" [ -x "$T/data5/cache/1.0.0/atlas-usage" ]
fake "$T/v11" v1.1
pin 1.1.0 "$asset" "$T/v11"
sed 's/"1.0.0"/"1.1.0"/' "$P/.claude-plugin/plugin.json" >"$T/pj" && mv "$T/pj" "$P/.claude-plugin/plugin.json"
rm -f "$REL/$asset"
DATA=$T/data5 run week; rc=$?
check "offline: exit 0" [ "$rc" = 0 ]
check "offline: older copy answers" has_out "fake v1 week"
check "offline: says which version" has_err "comes from the older v1.0.0"
cp "$T/v11" "$REL/$asset"
DATA=$T/data5 run week; rc=$?
check "back online: new version" has_out "fake v1.1 week"
check "back online: older copy pruned" [ ! -e "$T/data5/cache/1.0.0" ]

# --- 8. a copy on PATH: an old pinned release is passed over, an unknown build is used
setup 6 2.0.0
fake "$T/oldbin-v1" v1
pin 1.0.0 "$asset" "$T/oldbin-v1"
fake "$REL/$asset" v2
pin 2.0.0 "$asset" "$REL/$asset"
mkdir -p "$T/pathold" "$T/pathdev"
cp "$T/oldbin-v1" "$T/pathold/atlas-usage"
RUNPATH=$T/pathold:$BASEPATH DATA=$T/data6 run week; rc=$?
check "PATH old release: passed over" has_err "passed over"
check "PATH old release: current build runs" has_out "fake v2 week"
fake "$T/pathdev/atlas-usage" dev
RUNPATH=$T/pathdev:$BASEPATH DATA=$T/data6 run week; rc=$?
check "PATH own build: used" has_out "fake dev week"
# Offline with only the old PATH copy: it is the last resort.
setup 7 2.0.0
pin 1.0.0 "$asset" "$T/oldbin-v1"
fake "$T/v2b" v2
pin 2.0.0 "$asset" "$T/v2b"
RUNPATH=$T/pathold:$BASEPATH DATA=$T/data7 run week; rc=$?
check "offline, old PATH copy: last resort" has_out "fake v1 week"

# --- 9. too old for repeats: exit 4; a good copy's check is remembered
setup 8 1.0.0
fake "$REL/$asset" v1 old
pin 1.0.0 "$asset" "$REL/$asset"
DATA=$T/data8 run repeats --like "x" --json; rc=$?
check "too old: exit 4" [ "$rc" = 4 ]
check "too old: names the update command" has_err "/plugin marketplace update atlas"
setup 9 1.0.0
fake "$REL/$asset" v1
pin 1.0.0 "$asset" "$REL/$asset"
DATA=$T/data9 run debrief --detail low; rc=$?
check "debrief: runs" has_out "fake v1 debrief --detail low"
check "debrief: check remembered" sh -c "ls '$T/data9/cache/caps/' | grep -q '\\.debrief\$'"

# --- 10. ATLAS_USAGE_BIN
fake "$T/mine" mine
EXTRA="ATLAS_USAGE_BIN=$T/mine" DATA=$T/data9 run week; rc=$?
check "ATLAS_USAGE_BIN: used" has_out "fake mine week"
EXTRA="ATLAS_USAGE_BIN=$T/nope" DATA=$T/data9 run week; rc=$?
check "ATLAS_USAGE_BIN missing: exit 3" [ "$rc" = 3 ]

# --- 11. launcher-doctor runs nothing
FAKE_LOG=$T/runs.log DATA=$T/data9 run launcher-doctor; rc=$?
check "doctor: exit 0" [ "$rc" = 0 ]
check "doctor: names the copy" has_out "would run"
check "doctor: ran nothing" [ ! -e "$T/runs.log" ]
DATA=$T/data-doctor-empty run launcher-doctor
check "doctor: would download" has_out "one-time download"
check "doctor: downloaded nothing" [ ! -e "$T/data-doctor-empty/cache/1.0.0" ]

# --- 12. no plugin data folder: a per-user cache folder, not the plugin folder
setup 10 1.0.0
fake "$REL/$asset" v1
pin 1.0.0 "$asset" "$REL/$asset"
case $(uname -s) in
  Darwin) want_dir=$T/home/Library/Caches/atlas/skill/cache/1.0.0 ;;
  *) want_dir=$T/home/.cache/atlas/skill/cache/1.0.0 ;;
esac
DATA= run week; rc=$?
check "user cache: used" [ -x "$want_dir/atlas-usage" ]
check "user cache: not in the plugin folder" [ ! -e "$P/skills/atlas/bin/cache" ]

# --- 13. two runs at once: one download, both answer
setup 11 1.0.0
fake "$REL/$asset" v1
pin 1.0.0 "$asset" "$REL/$asset"
env -i PATH="$BASEPATH" HOME="$T/home" TMPDIR="$T" CLAUDE_PLUGIN_DATA="$T/data11" ATLAS_USAGE_TEST_SOURCE="$REL" \
  "$SHELL_UNDER_TEST" "$L" week >"$T/outA" 2>"$T/errA" &
env -i PATH="$BASEPATH" HOME="$T/home" TMPDIR="$T" CLAUDE_PLUGIN_DATA="$T/data11" ATLAS_USAGE_TEST_SOURCE="$REL" \
  "$SHELL_UNDER_TEST" "$L" week >"$T/outB" 2>"$T/errB"
wait
check "parallel: first answers" grep -q "fake v1 week" "$T/outA"
check "parallel: second answers" grep -q "fake v1 week" "$T/outB"
check "parallel: no lock left" sh -c "! ls -a '$T/data11/cache' | grep -q '^\\.lock'"
check "parallel: no work folder left" sh -c "! ls -a '$T/data11/cache' | grep -q '^\\.dl'"

# --- 14. a loopback address stands in for the release (http), when python3 is here
if command -v python3 >/dev/null 2>&1; then
  setup 12 1.0.0
  fake "$REL/$asset" v1
  pin 1.0.0 "$asset" "$REL/$asset"
  port=$((20000 + $$ % 20000))
  (cd "$REL" && exec python3 -m http.server "$port" --bind 127.0.0.1) >/dev/null 2>&1 &
  srv=$!
  i=0
  while [ $i -lt 50 ] && ! curl -fs "http://127.0.0.1:$port/" >/dev/null 2>&1; do sleep 0.1; i=$((i + 1)); done
  SRC=http://127.0.0.1:$port DATA=$T/data12 run week; rc=$?
  kill "$srv" 2>/dev/null
  check "loopback: downloads and runs" has_out "fake v1 week"
fi

printf '\n%s passed, %s failed (%s)\n' "$passed" "$failed" "$SHELL_UNDER_TEST"
[ "$failed" = 0 ]
