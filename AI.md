# tmux-auto-name

AI-powered tmux window auto-renamer that uses a local LLM (via Ollama) to give each window a short descriptive name based on what's running inside it.

## Stack

- Bash (the daemon and helper scripts)
- tmux (target: 3.3+)
- [Ollama](https://ollama.com) running locally
- Default model: `qwen2.5:1.5b` (configurable via `TAN_MODEL`)

## Layout

```
.
├── bin/
│   └── tmux-auto-name       # main daemon: loops, picks windows, renames
├── tmux-auto-name.tmux      # tpm-style plugin entrypoint (optional)
├── AI.md                    # this file (canonical project context)
├── CLAUDE.md → AI.md
├── OPENCODE.md → AI.md
├── GEMINI.md → AI.md
├── AGENTS.md → AI.md
└── README.md
```

## Run

```
ollama serve &                       # if not running
brew install ollama && ollama pull qwen2.5:1.5b
./bin/tmux-auto-name                 # foreground daemon
```

Or autostart from `.tmux.conf`:

```
run-shell '~/projects/tmux-auto-name/bin/tmux-auto-name &'
```

## Config (env vars)

| Var | Default | Meaning |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag |
| `TAN_INTERVAL` | `30` | Seconds between sweeps |
| `TAN_LINES` | `60` | Pane lines captured for context |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If 1, rename every window; else only "default-looking" ones (zsh/bash/fish/sh/numeric) |

## Conventions

- Names: lowercase, 1-3 words, no punctuation. Enforced by sanitizer, not just prompt.
- Renames are idempotent: if the new name equals the current one, no-op.
- Windows the user has manually renamed (any name not matching the default-shell allowlist) are left alone unless `TAN_RENAME_ALL=1`.

## Decisions

- 2026-05-17: bash over TypeScript/Bun. Daemon is ~80 LOC; no need for a runtime.
- 2026-05-17: target Ollama specifically (not OpenAI-compat) for v1. Local-first is the entire point. LM Studio support deferred.
- 2026-05-17: default model `qwen2.5:1.5b`. Task is "1-3 word label from short pane content" - no reasoning needed; 1.5b reliably follows the format and ~1 GB resident. 0.5b drops the format too often; 3b/7b add latency and RAM for no gain on this task.
- 2026-05-17: only rename "default-looking" window names by default. Respect user's manual renames.
