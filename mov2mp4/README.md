# mov2mp4

Convert MOV to MP4 — max 1080p, smaller file size. Strips audio by default.

**Requires:** [ffmpeg](https://ffmpeg.org/) (`brew install ffmpeg`)

The script is a single self-contained file. Install is optional — it only adds a shell alias so you can run `mov2mp4` from anywhere.

## Run without installing

Copy or download `mov2mp4.sh` and run it directly:

```bash
bash mov2mp4.sh recording.mov
bash mov2mp4.sh -a recording.mov compressed.mp4
bash mov2mp4.sh Screen Recording.mov
bash mov2mp4.sh "My Video.mov" "My Output.mp4"
```

Or, if executable:

```bash
chmod +x mov2mp4.sh
./mov2mp4.sh recording.mov
```

No other files from this directory are needed.

## Install (optional)

Checks for ffmpeg and installs it via Homebrew if missing. Then adds a `mov2mp4` alias to your shell rc file:

```bash
chmod +x mov2mp4.sh && ./mov2mp4.sh install
# or, without chmod:
bash mov2mp4.sh install
source ~/.zshrc   # or ~/.bashrc / ~/.bash_profile
```

Then run from anywhere:

```bash
mov2mp4 recording.mov
mov2mp4 -a recording.mov compressed.mp4
mov2mp4 recording.mov compressed.mp4 30 slow
mov2mp4 Screen Recording.mov
mov2mp4 "My Video.mov" "My Output.mp4"
```

Paths with spaces work unquoted or quoted — the script joins split arguments into input/output paths.

## Update

Install only adds an alias pointing at `mov2mp4.sh` in this directory — nothing is copied elsewhere. To get a newer version, pull or replace the file here; the next `mov2mp4` run uses it automatically. No need to run `install` again.

If you move this directory, run `uninstall` then `install` from the new location (or update the alias path in your shell rc file).

| Flag | Description |
|------|-------------|
| `-a`, `--keep-audio` | Keep audio (re-encoded as AAC 128k) |
| `-v`, `--verbose` | Show conversion settings and ffmpeg output (off by default) |

| Argument | Default | Description |
|----------|---------|-------------|
| `output.mp4` | same name, `.mp4` | Output path |
| `crf` | `28` | Quality/size tradeoff (18–32, higher = smaller) |
| `preset` | `slow` | x264 preset (`ultrafast`..`veryslow`) |

## Uninstall

```bash
./mov2mp4.sh uninstall
```
