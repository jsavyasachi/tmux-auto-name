# tmux-auto-name

AI-powered tmux window auto-renamer driven by a local LLM via Ollama. AI-coder aware: when Claude Code, Codex, OpenCode, Gemini, Goose, Aider, or Droid is running in a window, names it `<repo>: <task>` based on what you're actually working on.

## Stack

<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>
<a href="https://github.com/tmux/tmux"><img src="https://img.shields.io/badge/tmux-1BB91F?style=flat&logo=tmux&logoColor=white" alt="tmux" /></a>
<a href="https://ollama.com"><img src="https://img.shields.io/badge/Ollama-000000?style=flat&logo=ollama&logoColor=white" alt="Ollama" /></a>
<a href="https://qwenlm.github.io/"><img src="https://img.shields.io/badge/Qwen%202.5-615CED?style=flat&logo=alibabacloud&logoColor=white" alt="Qwen 2.5" /></a>

## How it works

Two modes:

- **Event-driven (recommended).** tmux hooks fire on `after-new-window` and `after-new-session`. The script waits `TAN_WATCH_DELAY` seconds (default 120), then captures the pane content, asks the local model for a label, and renames the window once. No background polling, no jitter.
- **Daemon (polling).** Sweeps every `TAN_INTERVAL` seconds. Heavier, but reacts to long-running task changes without you doing anything.

For windows running an AI coder, the script uses `<repo>: <task>` (e.g. `folio: dashboard fix`) - repo comes from the pane's cwd (git toplevel basename), task is a 1-3 word LLM summary. Otherwise: a generic 1-3 word label.

By default, only windows whose names still look like defaults (`zsh`, `bash`, `sh`, `fish`, numeric, empty) or already-AI-named windows (`name: task`) get touched. Manually-named windows are left alone unless `TAN_RENAME_ALL=1`.

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
# Rename windows 2 min after they open
set-hook -g after-new-window  'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'
set-hook -g after-new-session 'run-shell -b "~/projects/tmux-auto-name/bin/tmux-auto-name --watch #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1"'

# prefix + N: manually re-rename the current window
bind N run-shell '~/projects/tmux-auto-name/bin/tmux-auto-name --once #{session_name}:#{window_index} >>/tmp/tmux-auto-name.log 2>&1'
```

Reload: `tmux source-file ~/.tmux.conf`.

## Use - daemon

```
~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tmux-auto-name.log 2>&1 &
```

Or autostart from `~/.tmux.conf`:

```
run-shell 'pgrep -f tmux-auto-name >/dev/null || ~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tmux-auto-name.log 2>&1 &'
```

## CLI

```
tmux-auto-name                       # daemon (polls every TAN_INTERVAL)
tmux-auto-name --once <target>       # rename one window now (e.g. main:3)
tmux-auto-name --watch <target>      # sleep TAN_WATCH_DELAY, then rename once
tmux-auto-name --sweep               # one full sweep over all windows, then exit
```

## Config

| Var | Default | Purpose |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag |
| `TAN_INTERVAL` | `30` | Seconds between sweeps (daemon mode) |
| `TAN_WATCH_DELAY` | `120` | Seconds to wait in `--watch` before renaming |
| `TAN_LINES` | `80` | Pane lines sent as context |
| `TAN_MAXLEN` | `32` | Max final window-name length |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If `1`, rename every window every pass, even manually-named ones |

## License

MIT.
