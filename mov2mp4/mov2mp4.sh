#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
MARKER="# spellbook: mov2mp4"

usage() {
  cat <<'EOF'
Usage: mov2mp4.sh [options] <input.mov> [output.mp4] [crf] [preset]
       mov2mp4.sh install
       mov2mp4.sh uninstall

Convert MOV to MP4, max 1080p, smaller file size. Audio is stripped by default.

Options:
  -a, --keep-audio  Include audio (re-encoded as AAC 128k)

Arguments:
  input.mov   Source video file (required)
  output.mp4  Output path (default: same name with .mp4 extension)
  crf         Quality/size tradeoff, 18–32 (default: 28, higher = smaller)
  preset      x264 preset: ultrafast..veryslow (default: slow)

Examples:
  mov2mp4.sh recording.mov
  mov2mp4.sh -a recording.mov compressed.mp4
  mov2mp4.sh recording.mov compressed.mp4 30 slow

See README.md in this directory for installation.
EOF
}

shell_rc_file() {
  local shell_name
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  case "$shell_name" in
    zsh)
      echo "$HOME/.zshrc"
      ;;
    bash)
      if [[ -f "$HOME/.bashrc" ]]; then
        echo "$HOME/.bashrc"
      else
        echo "$HOME/.bash_profile"
      fi
      ;;
    fish)
      echo "$HOME/.config/fish/config.fish"
      ;;
    *)
      echo "Unsupported shell: $shell_name (supported: zsh, bash, fish)" >&2
      return 1
      ;;
  esac
}

ensure_ffmpeg() {
  if command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg: $(command -v ffmpeg)"
    return 0
  fi

  echo "ffmpeg not found, attempting install..."

  if command -v brew >/dev/null 2>&1; then
    brew install ffmpeg
    echo "ffmpeg installed"
    return 0
  fi

  echo "Error: ffmpeg not found and Homebrew is not available." >&2
  echo "Install ffmpeg manually: https://ffmpeg.org/download.html" >&2
  return 1
}

install_cmd() {
  local rc_file shell_name alias_line

  ensure_ffmpeg || exit 1

  rc_file="$(shell_rc_file)"
  shell_name="$(basename "${SHELL:-/bin/bash}")"

  if grep -Fq "$MARKER" "$rc_file" 2>/dev/null; then
    echo "Already installed in $rc_file"
    return 0
  fi

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  case "$shell_name" in
    fish)
      alias_line="$MARKER
alias mov2mp4 '$SCRIPT_PATH'"
      ;;
    *)
      alias_line="$MARKER
alias mov2mp4='$SCRIPT_PATH'"
      ;;
  esac

  printf '\n%s\n' "$alias_line" >> "$rc_file"
  chmod +x "$SCRIPT_PATH"

  echo "Added mov2mp4 to $rc_file"
  echo "Made $SCRIPT_PATH executable"
  echo "Restart your shell or run: source $rc_file"
}

uninstall_cmd() {
  local rc_file

  rc_file="$(shell_rc_file)"

  if [[ ! -f "$rc_file" ]] || ! grep -Fq "$MARKER" "$rc_file"; then
    echo "mov2mp4 is not installed in $rc_file"
    return 0
  fi

  awk -v marker="$MARKER" '
    $0 == marker { skip = 1; next }
    skip && /^alias mov2mp4=/ { skip = 0; next }
    skip && /^alias mov2mp4 / { skip = 0; next }
    { print }
  ' "$rc_file" > "${rc_file}.tmp"
  mv "${rc_file}.tmp" "$rc_file"

  echo "Removed mov2mp4 from $rc_file"
}

convert_mov() {
  local keep_audio="$1"
  shift
  local input="$1"
  local output="${2:-${input%.*}.mp4}"
  local crf="${3:-28}"
  local preset="${4:-slow}"
  local -a audio_args

  if [[ "$keep_audio" == 1 ]]; then
    audio_args=(-c:a aac -b:a 128k)
  else
    audio_args=(-an)
  fi

  if [[ ! -f "$input" ]]; then
    echo "Error: input file not found: $input" >&2
    exit 1
  fi

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg not found. Install with: brew install ffmpeg" >&2
    exit 1
  fi

  echo "Input:  $input"
  echo "Output: $output"
  echo "CRF:    $crf"
  echo "Preset: $preset"
  echo "Audio:  $([[ "$keep_audio" == 1 ]] && echo "keep (AAC 128k)" || echo "strip")"
  echo

  ffmpeg -i "$input" \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -crf "$crf" -preset "$preset" \
    "${audio_args[@]}" -movflags +faststart \
    -y "$output"

  echo
  echo "Done."
  ls -lh "$input" "$output"
}

case "${1:-}" in
  install)
    install_cmd
    ;;
  uninstall)
    uninstall_cmd
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    keep_audio=0
    positional=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -a|--keep-audio)
          keep_audio=1
          shift
          ;;
        *)
          positional+=("$1")
          shift
          ;;
      esac
    done

    if [[ ${#positional[@]} -lt 1 ]]; then
      usage
      exit 1
    fi

    convert_mov "$keep_audio" "${positional[@]}"
    ;;
esac
