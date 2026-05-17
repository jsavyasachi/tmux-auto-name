# tmux-auto-name

AI-powered tmux window auto-renamer driven by a local LLM via Ollama.

## Stack

<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>
<a href="https://github.com/tmux/tmux"><img src="https://img.shields.io/badge/tmux-1BB91F?style=flat&logo=tmux&logoColor=white" alt="tmux" /></a>
<a href="https://ollama.com"><img src="https://img.shields.io/badge/Ollama-000000?style=flat&logo=ollama&logoColor=white" alt="Ollama" /></a>
<a href="https://qwenlm.github.io/"><img src="https://img.shields.io/badge/Qwen%202.5-615CED?style=flat&logo=alibabacloud&logoColor=white" alt="Qwen 2.5" /></a>

## How it works

Every `TAN_INTERVAL` seconds, the daemon walks every tmux window in every session. For windows whose name still looks like a default (`zsh`, `bash`, `sh`, `fish`, or a bare number), it captures the last `TAN_LINES` lines of the pane and asks the local model for a 1-3 word label, then renames the window. Manually-renamed windows are left alone unless `TAN_RENAME_ALL=1`.

## Install

```
brew install ollama jq
ollama serve &
ollama pull qwen2.5:1.5b
git clone https://github.com/jsavyasachi/tmux-auto-name.git ~/projects/tmux-auto-name
chmod +x ~/projects/tmux-auto-name/bin/tmux-auto-name
```

Run it once foreground to test:

```
~/projects/tmux-auto-name/bin/tmux-auto-name
```

Autostart from `~/.tmux.conf`:

```
run-shell '~/projects/tmux-auto-name/bin/tmux-auto-name >/tmp/tan.log 2>&1 &'
```

## Config

| Var | Default | Purpose |
|---|---|---|
| `TAN_MODEL` | `qwen2.5:1.5b` | Ollama model tag |
| `TAN_INTERVAL` | `30` | Seconds between sweeps |
| `TAN_LINES` | `60` | Pane lines sent as context |
| `TAN_OLLAMA_HOST` | `http://localhost:11434` | Ollama API base |
| `TAN_RENAME_ALL` | `0` | If `1`, rename every window (including manually-named ones) |

## License

MIT.
