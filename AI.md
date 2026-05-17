# tmux-auto-name

AI-powered tmux window auto-renamer that uses a local LLM (via Ollama) to name each window from what's running inside it. AI-coder aware: when one of the supported agents (claude, codex, opencode, gemini, goose, aider, droid, crush, cursor, cody) is running in the window, the name becomes `<repo>: <task>` rather than a generic label.

## Stack

- Bash (single script, ~200 LOC)
- tmux 3.3+ (uses `set-hook`, `display-message -p`, `pane_title`)
- [Ollama](https://ollama.com) running locally
- Default model: `qwen2.5:1.5b` (configurable via `TAN_MODEL`)

## Layout

```
.
├── bin/
│   └── tmux-auto-name       # the script - daemon, --once, --watch, --sweep
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

Daemon (fallback for ongoing task tracking):

```
~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tmux-auto-name.log 2>&1 &
```

## CLI

```
tmux-auto-name                  # poll loop
tmux-auto-name --once <target>  # one rename now
tmux-auto-name --watch <target> # sleep TAN_WATCH_DELAY, then rename once
tmux-auto-name --sweep          # one full sweep, then exit
```

## Config (env vars)

| Var | Default | Meaning |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag |
| `TAN_INTERVAL` | `30` | Seconds between daemon sweeps |
| `TAN_WATCH_DELAY` | `120` | Seconds `--watch` sleeps before renaming |
| `TAN_LINES` | `80` | Pane lines captured for context |
| `TAN_MAXLEN` | `32` | Hard cap on final window-name length |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If `1`, rename every window each pass (including manually-named) |

## Conventions

- Names: lowercase, 1-3 words, no punctuation. Enforced by `sanitize_label`, not just the prompt.
- For AI windows: `<repo>: <task>`. Repo is `git rev-parse --show-toplevel` basename; falls back to `basename "$pane_current_path"`; falls back to the tool name.
- AI-coder windows are detected by substring match on `pane_current_command` against an allowlist (`claude|codex|opencode|gemini|goose|aider|droid|crush|cursor|cody`), OR by a bare version-number command (e.g. Claude Code shows up as `2.1.143` in `ps`).
- Renames are idempotent: if the new name equals the current, no-op.
- A non-default window name is treated as "user manually named it" and skipped, EXCEPT names containing `:` (we assume these are previous AI renames and keep refreshing them).

## Decisions

- 2026-05-17: bash over TypeScript/Bun. Single script, no runtime to install.
- 2026-05-17: target Ollama specifically (not OpenAI-compat) for v1. Local-first is the entire point. LM Studio support deferred.
- 2026-05-17: default model `qwen2.5:1.5b`. Task is "1-3 word label from short pane content" - no reasoning needed; 1.5b reliably follows the format and ~1 GB resident. 0.5b drops the format too often; 3b/7b add latency and RAM for no gain on this task.
- 2026-05-17: only rename "default-looking" window names by default. Respect user's manual renames.
- 2026-05-17: AI-coder-aware mode. Format `<repo>: <task>` so the status line tells you both project and current focus at a glance.
- 2026-05-17: detect Claude Code by version-string `pane_current_command` (`^[0-9]+\.[0-9]+(\.[0-9]+)?$`) since it appears as `2.1.143` in `ps`, not `claude`.
- 2026-05-17: event-driven (tmux hooks) is the recommended mode, not polling. Polling caused jitter as model output drifted between sweeps. Hooks: rename once 2 min after window opens, plus `prefix + N` for manual refresh.
- 2026-05-17: AI-named windows (those containing `:`) are still re-renameable in daemon mode without `TAN_RENAME_ALL=1`, since the task is expected to evolve.
