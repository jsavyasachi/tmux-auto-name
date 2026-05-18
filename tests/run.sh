#!/usr/bin/env bash
# Test harness for tmux-auto-name. Sources the script and exercises pure functions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Sandbox the cache so tests don't touch the user's real one.
export XDG_CACHE_HOME
XDG_CACHE_HOME="$(mktemp -d)"
trap 'rm -rf "$XDG_CACHE_HOME"' EXIT

# shellcheck disable=SC1091
source "$SCRIPT_DIR/bin/tmux-auto-name"

PASS=0
FAIL=0
FAILED_TESTS=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS+=("$label")
    printf '  FAIL %s\n    expected: %q\n    actual:   %q\n' "$label" "$expected" "$actual"
  fi
}

section() { printf '\n== %s ==\n' "$1"; }

section "sanitize_label"
assert_eq "trims and lowercases"           "hello-world"      "$(printf 'Hello World' | sanitize_label 24)"
assert_eq "drops punctuation"              "with-punctuation" "$(printf 'WITH PUNCTUATION!!!' | sanitize_label 24)"
assert_eq "caps at 3 words"                "one-two-three"    "$(printf 'one two three four five' | sanitize_label 32)"
assert_eq "truncates at maxlen"            "abcdefghij"       "$(printf 'abcdefghijklmnop' | sanitize_label 10)"
assert_eq "empty stays empty"              ""                 "$(printf '' | sanitize_label 24)"
assert_eq "only punctuation -> empty"      ""                 "$(printf '!!! ??? ...' | sanitize_label 24)"

section "detect_ai_tool"
assert_eq "claude direct"                  "claude"           "$(detect_ai_tool claude)"
assert_eq "codex with suffix"              "codex"            "$(detect_ai_tool codex-aarch64-a)"
assert_eq "claude version-string"          "claude"           "$(detect_ai_tool 2.1.143)"
assert_eq "claude 2-segment version"       "claude"           "$(detect_ai_tool 2.1)"
assert_eq "opencode"                       "opencode"         "$(detect_ai_tool opencode)"
assert_eq "vim not ai"                     ""                 "$(detect_ai_tool vim)"
assert_eq "empty cmd"                      ""                 "$(detect_ai_tool '')"
assert_eq "node not ai"                    ""                 "$(detect_ai_tool node)"

section "detect_fg_cmd"
assert_eq "vim"                            "vim"              "$(detect_fg_cmd vim)"
assert_eq "nvim before vim"                "nvim"             "$(detect_fg_cmd nvim)"
assert_eq "node"                           "node"             "$(detect_fg_cmd node)"
assert_eq "shell -> empty"                 ""                 "$(detect_fg_cmd zsh)"
assert_eq "unknown -> empty"               ""                 "$(detect_fg_cmd weirdtool)"

section "format_name"
assert_eq "ai with slug"                   "claude:myrepo:auth-fix"  "$(format_name claude myrepo auth-fix '')"
assert_eq "ai without slug"                "claude:myrepo"           "$(format_name claude myrepo '' '')"
assert_eq "non-ai repo only"               "myrepo"                  "$(format_name '' myrepo '' '')"
assert_eq "non-ai repo + fg cmd"           "myrepo:vim"              "$(format_name '' myrepo '' vim)"
assert_eq "nothing -> empty"               ""                        "$(format_name '' '' '' '')"
assert_eq "truncate long segments"         "claude:tmux-auto-name:dashboard-fi" \
                                           "$(format_name claude tmux-auto-name dashboard-fixup-task '')"

section "repo_for_path"
TMP_GIT="$(mktemp -d)"
(cd "$TMP_GIT" && git init -q -b main && git config user.email t@t && git config user.name t)
# Resolve symlinks (macOS /tmp -> /private/tmp) so basename comparison is reliable.
TMP_GIT_REAL="$(cd "$TMP_GIT" && pwd -P)"
assert_eq "in repo -> basename"            "$(basename "$TMP_GIT_REAL")"  "$(repo_for_path "$TMP_GIT")"
TMP_NONGIT="$(mktemp -d)"
TMP_NONGIT_REAL="$(cd "$TMP_NONGIT" && pwd -P)"
assert_eq "no repo -> basename of path"    "$(basename "$TMP_NONGIT_REAL")"  "$(repo_for_path "$TMP_NONGIT")"
assert_eq "empty path -> empty"            ""                 "$(repo_for_path '')"
rm -rf "$TMP_GIT" "$TMP_NONGIT"

section "cache"
# cache_get returns 1 (no output) on miss; capture both.
miss="$(cache_get '%1' claude myrepo || true)"
assert_eq "miss -> empty"                  ""                 "$miss"
cache_set '%1' claude myrepo 'auth-fix'
assert_eq "hit after set"                  "auth-fix"         "$(cache_get '%1' claude myrepo)"
cache_set '%1' claude myrepo 'new-task'
assert_eq "update overwrites"              "new-task"         "$(cache_get '%1' claude myrepo)"
cache_set '%2' codex other 'something'
assert_eq "second key unaffected"          "new-task"         "$(cache_get '%1' claude myrepo)"
assert_eq "second key reads back"          "something"        "$(cache_get '%2' codex other)"
# GC: simulate %2 going away by passing live=%1
cache_gc_with_live $'%1\n'
assert_eq "gc keeps live"                  "new-task"         "$(cache_get '%1' claude myrepo)"
miss2="$(cache_get '%2' codex other || true)"
assert_eq "gc drops dead"                  ""                 "$miss2"

section "is_managed_name"
assert_eq "default zsh"                    "1"                "$(is_managed_name zsh '' && echo 1 || echo 0)"
assert_eq "default empty"                  "1"                "$(is_managed_name '' '' && echo 1 || echo 0)"
assert_eq "matches cmd"                    "1"                "$(is_managed_name vim vim && echo 1 || echo 0)"
assert_eq "ai-tool-prefixed"               "1"                "$(is_managed_name 'claude:repo:task' claude && echo 1 || echo 0)"
assert_eq "user-renamed left alone"        "0"                "$(is_managed_name 'my-thing' '' && echo 1 || echo 0)"
assert_eq "numeric tmux default"           "1"                "$(is_managed_name '3' '' && echo 1 || echo 0)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -gt 0 ]]; then
  printf 'Failed:\n'
  printf '  - %s\n' "${FAILED_TESTS[@]}"
  exit 1
fi
