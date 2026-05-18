# tmux-auto-name

Deterministic tmux window auto-renamer. Names windows as `<tool>:<repo>:<slug>` when an AI coding agent is running (claude, codex, opencode, gemini, goose, aider, droid, crush, cursor, cody), `<repo>` or `<repo>:<fg_cmd>` for plain shells in a git repo, and leaves everything else alone. The slug is the only thing that touches a local LLM (Ollama), and it's cached per `(pane_id, tool, repo)` so window names don't twitch between sweeps.

## Stack

- Bash (single script, ~250 LOC) + a sourceable function layout for tests
- tmux 3.3+ (uses `set-hook`, `display-message -p`, `pane_id`)
- [Ollama](https://ollama.com) running locally (only for AI-pane slugs)
- Default model: `qwen2.5:1.5b` (configurable via `TAN_MODEL`)
- Cache: `${XDG_CACHE_HOME:-~/.cache}/tmux-auto-name/slugs.tsv`

## Layout

```
.
├── bin/
│   └── tmux-auto-name       # the script: daemon, --once, --watch, --sweep
├── tests/
│   └── run.sh               # bash test harness (sources the script, no tmux/Ollama needed)
├── AI.md                    # this file (canonical project context)
├── CLAUDE.md → AI.md
├── OPENCODE.md → AI.md
├── GEMINI.md → AI.md
├── AGENTS.md → AI.md
└── README.md
```

## Run

Event-driven (preferred):

```
# in ~/.tmux.conf
set-hook -g after-new-window  'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'
set-hook -g after-new-session 'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'
bind N run-shell '~/projects/tmux-auto-name/bin/tmux-auto-name --once #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1'
```

Daemon:

```
~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tmux-auto-name.log 2>&1 &
```

Tests:

```
bash tests/run.sh
```

## CLI

```
tmux-auto-name                  # poll loop
tmux-auto-name --once <target>  # one rename now, force LLM regenerate (bypasses cache)
tmux-auto-name --watch <target> # sleep TAN_WATCH_DELAY, then rename once (cache-respecting)
tmux-auto-name --sweep          # one full sweep + cache GC, then exit
```

## Config (env vars)

| Var | Default | Meaning |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag (slug only) |
| `TAN_INTERVAL` | `30` | Seconds between daemon sweeps |
| `TAN_WATCH_DELAY` | `120` | Seconds `--watch` sleeps before renaming |
| `TAN_LINES` | `80` | Pane lines captured for context |
| `TAN_MAXLEN` | `40` | Hard cap on final window-name length |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If `1`, rename every window each pass (including manually-named) |

## Conventions

- Output format: `<tool>:<repo>:<slug>` for AI; `<repo>` or `<repo>:<fg_cmd>` for plain shells in a git repo; nothing for everything else.
- Per-segment caps: tool 12, repo 14, slug 12. Truncated independently so the slug never gets lopped off.
- AI tool detection: substring match on `pane_current_command` against `(claude|codex|opencode|gemini|goose|aider|droid|crush|cursor|cody)`, OR a bare version-number command (`^[0-9]+\.[0-9]+(\.[0-9]+)?$`) which is almost always Claude Code (`2.1.143` in `ps`).
- Foreground cmd recognition (non-AI): `(nvim|vim|nano|emacs|less|man|psql|nodemon|node|python|ruby|cargo|npm|pnpm|yarn|make|docker|k9s|htop|btop|lazygit|tig|gh|ssh|vi)`. Longer alternatives first so substring match doesn't shadow them.
- Slugs are cached per `(pane_id, tool, repo)` and never auto-refresh. `--once` is the only path that regenerates. Dead pane_ids are GC'd on every sweep.
- A window is considered "ours to overwrite" if its name is default-looking, matches the current cmd (tmux auto-rename), or starts with `<known-tool>:`. Anything else is treated as a user manual rename and left alone (unless `TAN_RENAME_ALL=1`).
- The script is sourceable: dispatch is guarded by `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` so `tests/run.sh` can pull in functions without triggering CLI parsing or dependency checks.

## Decisions

- 2026-05-17: bash over TypeScript/Bun. Single script, no runtime to install.
- 2026-05-17: target Ollama specifically (not OpenAI-compat) for v1. Local-first is the entire point. LM Studio support deferred.
- 2026-05-17: default model `qwen2.5:1.5b`. Task is "1-3 word label from short pane content" - no reasoning needed; 1.5b reliably follows the format and ~1 GB resident. 0.5b drops the format too often; 3b/7b add latency and RAM for no gain on this task.
- 2026-05-17: only rename "default-looking" window names by default. Respect user's manual renames.
- 2026-05-17: detect Claude Code by version-string `pane_current_command` (`^[0-9]+\.[0-9]+(\.[0-9]+)?$`) since it appears as `2.1.143` in `ps`, not `claude`.
- 2026-05-17: event-driven (tmux hooks) is the recommended mode, not polling. Polling caused jitter as model output drifted between sweeps. Hooks: rename once 2 min after window opens, plus `prefix + N` for manual refresh.
- 2026-05-17: format flipped from `<repo>: <task>` to `<tool>:<repo>:<slug>`. Tool prefix tells you at a glance which agent is running where; the repo segment stays load-bearing for at-a-glance project ID. Supersedes the earlier "AI-coder-aware <repo>: <task>" decision.
- 2026-05-17: slug is LLM-generated once per `(pane_id, tool, repo)` and cached forever. No auto-refresh - status-line names should not twitch. `--once` is the only way to regenerate; dead pane_ids GC on sweep. Supersedes the earlier "AI-named windows are still re-renameable in daemon mode" decision.
- 2026-05-17: non-AI windows are pure deterministic derivation (`<repo>` or `<repo>:<fg_cmd>`). No LLM call for the common case. Ollama is only required if you actually run AI agents in tmux.
- 2026-05-17: pane-id-keyed cache (not repo+cwd-keyed). Killing + reopening a window regenerates the slug. Tradeoff is intentional: two concurrent claude sessions in the same repo get distinct names.
- 2026-05-17: long tool names in the prefix (`claude:`, `codex:`) over short tags (`cl:`, `cx:`). Clarity over status-line density.
- 2026-05-17: removed empty-alternative `|)` from `DEFAULT_NAME_RE` - macOS bash 5 regex engine doesn't match strings against a trailing empty alternative. Empty-name check is now a separate `[[ -z "$name" ]]`. Latent bug in the original.
- 2026-05-17: refactor introduced `tests/run.sh` (no tmux/Ollama needed). Script made sourceable via `BASH_SOURCE` guard so pure functions can be unit-tested in isolation.
