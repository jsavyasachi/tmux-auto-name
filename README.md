# tmux-auto-name

Deterministic tmux window auto-renamer. AI-coder aware: when Claude Code, Codex, OpenCode, Gemini, Goose, Aider, Droid, Crush, Cursor, or Cody is running in a window, names it `<tool>:<repo>:<slug>`. The slug is generated once per pane via a local LLM (Ollama) and cached forever, so status-line names stop twitching between sweeps. Non-AI windows are pure string derivation - no LLM call.

## Stack

<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>
<a href="https://github.com/tmux/tmux"><img src="https://img.shields.io/badge/tmux-1BB91F?style=flat&logo=tmux&logoColor=white" alt="tmux" /></a>
<a href="https://ollama.com"><img src="https://img.shields.io/badge/Ollama-000000?style=flat&logo=ollama&logoColor=white" alt="Ollama" /></a>
<a href="https://qwenlm.github.io/"><img src="https://img.shields.io/badge/Qwen%202.5-615CED?style=flat&logo=alibabacloud&logoColor=white" alt="Qwen 2.5" /></a>

## Naming

| Pane contents | Window name |
|---|---|
| AI coder running, in a git repo | `claude:tmux-auto-name:auth-fix` |
| AI coder running, no repo | `claude:claude` (tool name doubles as repo) |
| Plain shell in a git repo | `tmux-auto-name` |
| Recognized foreground cmd (vim, node, psql, ...) in a repo | `tmux-auto-name:vim` |
| Otherwise | left alone |

Each segment has its own cap (tool: 12, repo: 14, slug: 12). Total is capped at `TAN_MAXLEN`.

## Determinism

- The slug is computed once per `(pane_id, tool, repo)` and cached at `${XDG_CACHE_HOME:-~/.cache}/tmux-auto-name/slugs.tsv`. It does not change as pane content drifts.
- `--once` (bound to prefix+N) **bypasses the cache** - this is your "regenerate this slug" gesture.
- Killing and reopening a window means a fresh slug (different `pane_id`). Dead entries are GC'd on every sweep.
- Non-AI windows have no LLM input at all. Their name is pure `repo` / `repo:cmd`.

## Modes

- **Event-driven (recommended).** tmux hooks fire on `after-new-window` and `after-new-session`. The script waits `TAN_WATCH_DELAY` seconds, then renames once. No polling, no jitter.
- **Daemon.** Sweeps every `TAN_INTERVAL` seconds. Useful if you want non-AI windows to react to foreground command changes without manual refresh.

By default only windows whose names look default (`zsh`, `bash`, `sh`, `fish`, numeric, empty), match the current pane command, or are already prefixed with one of our known AI tool labels get rewritten. Manually-named windows are left alone unless `TAN_RENAME_ALL=1`.

## Install

```
brew install ollama jq
ollama serve &
ollama pull qwen2.5:1.5b
git clone https://github.com/jsavyasachi/tmux-auto-name.git ~/projects/tmux-auto-name
chmod +x ~/projects/tmux-auto-name/bin/tmux-auto-name
```

## Use - event-driven (recommended)

Add to `~/.tmux.conf`:

```
set-hook -g after-new-window  'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'
set-hook -g after-new-session 'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'

# prefix + N: regenerate the slug for the current window (bypasses cache)
bind N run-shell '~/projects/tmux-auto-name/bin/tmux-auto-name --once #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1'
```

Reload: `tmux source-file ~/.tmux.conf`.

## Use - daemon

```
~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tmux-auto-name.log 2>&1 &
```

## CLI

```
tmux-auto-name                       # daemon (polls every TAN_INTERVAL)
tmux-auto-name --once <target>       # rename one window now, force LLM regenerate
tmux-auto-name --watch <target>      # sleep TAN_WATCH_DELAY, then rename once (cache-respecting)
tmux-auto-name --sweep               # one full sweep over all windows, then exit
```

## Config

| Var | Default | Purpose |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag (slug only) |
| `TAN_INTERVAL` | `30` | Seconds between sweeps (daemon mode) |
| `TAN_WATCH_DELAY` | `120` | Seconds to wait in `--watch` before renaming |
| `TAN_LINES` | `80` | Pane lines sent as LLM context |
| `TAN_MAXLEN` | `40` | Hard cap on final window-name length |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If `1`, rename every window every pass, even manually-named ones |

## Tests

```
bash tests/run.sh
```

Covers `sanitize_label`, `detect_ai_tool`, `detect_fg_cmd`, `format_name`, `repo_for_path`, cache read/write/GC, and `is_managed_name`. No tmux or Ollama required.

## License

MIT.
