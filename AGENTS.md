# Spellbook — Agent Guide

Small, self-contained shell scripts for specific tasks. Read this before adding or modifying scripts.

## Layout

Each script lives in its own directory:

```
scriptname/
├── scriptname.sh   # single self-contained executable
└── README.md       # human docs (usage, install, flags)
```

Root `README.md` is an index only — link to each script directory, don't duplicate full usage docs here.

## Script conventions

Follow `mov2mp4/` as the reference implementation.

- **Bash**, with `#!/usr/bin/env bash` and `set -euo pipefail`
- **Self-contained** — one `.sh` file holds all logic; no shared libraries or config files
- **Runnable without install** — `bash scriptname.sh …` must work with no setup beyond external deps
- **Install is optional** — adds a shell alias so the command works from anywhere
- **`--help`** — usage in-script; point to local `README.md` for install details (don't duplicate long install docs in `--help`)

Resolve paths from the script location:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
```

## Install / uninstall pattern

Scripts that support global use should implement:

| Subcommand   | Behavior |
|--------------|----------|
| `install`    | Check/install deps, `chmod +x` the script, append alias to shell rc |
| `uninstall`  | Remove alias block from shell rc |

Install details:

- Marker comment in rc file: `# spellbook: <name>` (used for idempotent install and clean uninstall)
- Alias name matches the command users expect (e.g. `mov2mp4`, not `mov2mp4.sh`)
- Support zsh (`.zshrc`), bash (`.bashrc` or `.bash_profile`), fish (`~/.config/fish/config.fish`)
- Skip if marker already present (idempotent)
- Check external dependencies during `install`; attempt Homebrew install when available
- **No copy on install** — the alias points at the script file in place. Editing or pulling updates to that file takes effect immediately; reinstall is not required unless the script was moved to a new path (then `uninstall` + `install`, or update the alias path manually)

## README conventions

Each script directory gets its own `README.md` covering:

1. What it does (one line)
2. External requirements (e.g. ffmpeg)
3. **Run without installing** — emphasize single-file, copy-anywhere usage
4. **Install (optional)** — only if the script supports it
5. **Update** — if installed, note that install is an alias only; pull or edit the script in place (no reinstall). Mention reinstall only when the script directory moves
6. Usage examples, flags, and argument defaults

Keep READMEs short. Don't add per-script agent files unless a script becomes unusually complex.

## Adding a new script

1. Create `scriptname/scriptname.sh` following conventions above
2. Create `scriptname/README.md`
3. Add one line to root `README.md` under **Scripts**
4. Prefer minimal scope — solve one task well, avoid abstractions shared across scripts

## Principles

- **Minimize scope** — smallest correct change; don't refactor unrelated scripts
- **No over-engineering** — no shared utils package, no framework; copy small patterns if needed
- **Don't commit unless asked** — user controls git history
- **Test with** `bash -n scriptname.sh` for syntax; run `--help` to verify usage output

## Current scripts

| Directory | Command | Purpose |
|-----------|---------|---------|
| [mov2mp4](mov2mp4/) | `mov2mp4` | Convert MOV → MP4 (max 1080p, strip audio by default, `-a` to keep) |
