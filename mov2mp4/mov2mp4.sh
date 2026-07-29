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
  -v, --verbose     Show conversion settings and ffmpeg output (default: progress bar)

Arguments:
  input.mov   Source video file (required)
  output.mp4  Output path (default: same name with .mp4 extension)
  crf         Quality/size tradeoff, 18–32 (default: 28, higher = smaller)
  preset      x264 preset: ultrafast..veryslow (default: slow)

Examples:
  mov2mp4.sh recording.mov
  mov2mp4.sh -a recording.mov compressed.mp4
  mov2mp4.sh recording.mov compressed.mp4 30 slow
  mov2mp4.sh Screen Recording.mov
  mov2mp4.sh "Screen Recording.mov" "My Output.mp4"

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

X264_PRESETS=(ultrafast superfast veryfast faster fast medium slow slower veryslow placebo)

is_x264_preset() {
  local candidate="$1" preset
  for preset in "${X264_PRESETS[@]}"; do
    [[ "$candidate" == "$preset" ]] && return 0
  done
  return 1
}

is_crf_value() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 18 && $1 <= 32 ))
}

join_args() {
  local joined="" part
  for part in "$@"; do
    if [[ -n "$joined" ]]; then
      joined="$joined $part"
    else
      joined="$part"
    fi
  done
  printf '%s' "$joined"
}

# Join argv fragments so paths with spaces work without quoting.
parse_convert_args() {
  local -a args=("$@")
  local crf=28 preset=slow
  local last_idx input output accum="" i j out_accum

  if [[ ${#args[@]} -gt 0 ]]; then
    last_idx=$((${#args[@]} - 1))
    if is_x264_preset "${args[$last_idx]}"; then
      preset="${args[$last_idx]}"
      args=("${args[@]:0:$last_idx}")
    fi
  fi

  if [[ ${#args[@]} -gt 0 ]]; then
    last_idx=$((${#args[@]} - 1))
    if is_crf_value "${args[$last_idx]}"; then
      crf="${args[$last_idx]}"
      args=("${args[@]:0:$last_idx}")
    fi
  fi

  if [[ ${#args[@]} -eq 0 ]]; then
    echo "Error: input file required" >&2
    exit 1
  fi

  input=""
  output=""

  for (( i=0; i<${#args[@]}; i++ )); do
    if [[ -n "$accum" ]]; then
      accum="$accum ${args[i]}"
    else
      accum="${args[i]}"
    fi
    if [[ -f "$accum" ]]; then
      input="$accum"
      accum=""
      i=$((i + 1))
      break
    fi
  done

  if [[ -n "$input" ]]; then
    if [[ $i -lt ${#args[@]} ]]; then
      output="$(join_args "${args[@]:i}")"
    fi
  elif [[ ${#args[@]} -eq 1 ]]; then
    input="${args[0]}"
  else
    for (( j=1; j<${#args[@]}; j++ )); do
      out_accum="$(join_args "${args[@]:j}")"
      accum="$(join_args "${args[@]:0:j}")"
      if [[ "$out_accum" =~ \.[mM][pP]4$ && "$accum" =~ \.(mov|MOV|mp4|MP4)$ ]]; then
        input="$accum"
        output="$out_accum"
        break
      fi
    done
    if [[ -z "$input" ]]; then
      input="$(join_args "${args[@]}")"
    fi
  fi

  if [[ -z "$output" && -n "$input" ]]; then
    output="${input%.*}.mp4"
  fi

  PARSED_INPUT="$input"
  PARSED_OUTPUT="$output"
  PARSED_CRF="$crf"
  PARSED_PRESET="$preset"
}

file_size_human() {
  ls -lh "$1" | awk '{print $5}'
}

file_size_bytes() {
  wc -c < "$1" | tr -d ' '
}

size_change_msg() {
  local input="$1" output="$2"
  local input_bytes output_bytes

  input_bytes="$(file_size_bytes "$input")"
  output_bytes="$(file_size_bytes "$output")"

  if (( input_bytes == 0 )); then
    return 0
  fi

  awk -v inp="$input_bytes" -v out="$output_bytes" '
    function fmt_ratio(r,   s) {
      if (r >= 10) {
        s = sprintf("%.0f", r)
      } else if (r == int(r + 0.001)) {
        s = sprintf("%.0f", r)
      } else {
        s = sprintf("%.1f", r)
      }
      return s
    }
    BEGIN {
      if (out == inp) {
        print "same size"
        exit
      }
      if (out < inp) {
        print fmt_ratio(inp / out) " times smaller"
      } else {
        print fmt_ratio(out / inp) " times bigger"
      }
    }
  '
}

print_file_summary() {
  printf '%s | %s\n' "$1" "$(file_size_human "$1")"
}

media_duration_ms() {
  local duration

  if ! command -v ffprobe >/dev/null 2>&1; then
    echo 0
    return 0
  fi

  duration="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null || true)"
  if [[ -z "$duration" ]]; then
    echo 0
    return 0
  fi

  awk -v d="$duration" 'BEGIN { printf "%.0f\n", d * 1000 }'
}

terminal_cols() {
  local cols

  cols="$(tput cols 2>/dev/null || echo 80)"
  if [[ "$cols" -lt 30 ]]; then
    cols=30
  fi
  printf '%s' "$cols"
}

progress_bar_string() {
  local filled="$1" empty="$2" bar=""

  if (( filled > 0 )); then
    bar="$(printf '%*s' "$filled" '' | tr ' ' '█')"
  fi
  if (( empty > 0 )); then
    bar="${bar}$(printf '%*s' "$empty" '' | tr ' ' '░')"
  fi
  printf '%s' "$bar"
}

render_progress_bar() {
  local pct="$1" cols="$2" label="Converting"
  local overhead bar_width filled empty

  overhead=$((${#label} + 9))
  bar_width=$((cols - overhead))
  if (( bar_width < 10 )); then
    bar_width=10
  fi

  filled=$((pct * bar_width / 100))
  empty=$((bar_width - filled))

  printf '\r%s [%s] %3d%%' "$label" "$(progress_bar_string "$filled" "$empty")" "$pct"
}

run_ffmpeg_with_progress() {
  local verbose="$1" input="$2" duration_ms cols pct out_time_ms progress_fifo ffmpeg_pid status
  shift 2
  local -a ffmpeg_args=("$@")

  if [[ "$verbose" == 1 ]]; then
    ffmpeg "${ffmpeg_args[@]}"
    return $?
  fi

  duration_ms="$(media_duration_ms "$input")"
  cols="$(terminal_cols)"

  if [[ ! -t 1 ]] || (( duration_ms <= 0 )); then
    ffmpeg "${ffmpeg_args[@]}"
    return $?
  fi

  progress_fifo="$(mktemp -u "${TMPDIR:-/tmp}/mov2mp4-progress.XXXXXX")"
  mkfifo "$progress_fifo"

  ffmpeg "${ffmpeg_args[@]}" -progress "$progress_fifo" &
  ffmpeg_pid=$!

  while IFS= read -r line; do
    case "$line" in
      out_time_ms=*)
        out_time_ms="${line#out_time_ms=}"
        if [[ "$out_time_ms" =~ ^[0-9]+$ ]]; then
          pct=$((out_time_ms * 100 / duration_ms))
          if (( pct > 100 )); then
            pct=100
          fi
          render_progress_bar "$pct" "$cols"
        fi
        ;;
      progress=end)
        break
        ;;
    esac
  done < "$progress_fifo"

  wait "$ffmpeg_pid"
  status=$?
  rm -f "$progress_fifo"
  render_progress_bar 100 "$cols"
  printf '\n'
  return "$status"
}

convert_mov() {
  local keep_audio="$1"
  local verbose="$2"
  shift 2
  local -a audio_args ffmpeg_log_args

  parse_convert_args "$@"

  local input="$PARSED_INPUT"
  local output="$PARSED_OUTPUT"
  local crf="$PARSED_CRF"
  local preset="$PARSED_PRESET"

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

  if [[ "$verbose" == 1 ]]; then
    ffmpeg_log_args=()
  else
    ffmpeg_log_args=(-hide_banner -loglevel error -nostats)
  fi

  if [[ "$verbose" == 1 ]]; then
    echo "Input:  $input"
    echo "Output: $output"
    echo "CRF:    $crf"
    echo "Preset: $preset"
    echo "Audio:  $([[ "$keep_audio" == 1 ]] && echo "keep (AAC 128k)" || echo "strip")"
    echo
  fi

  run_ffmpeg_with_progress "$verbose" "$input" \
    "${ffmpeg_log_args[@]}" -i "$input" \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2" \
    -c:v libx264 -crf "$crf" -preset "$preset" \
    "${audio_args[@]}" -movflags +faststart \
    -y "$output"

  local size_msg

  size_msg="$(size_change_msg "$input" "$output")"
  if [[ -n "$size_msg" ]]; then
    echo "Done. $size_msg"
  else
    echo "Done."
  fi
  print_file_summary "$input"
  print_file_summary "$output"
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
    verbose=0
    positional=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -a|--keep-audio)
          keep_audio=1
          shift
          ;;
        -v|--verbose)
          verbose=1
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

    convert_mov "$keep_audio" "$verbose" "${positional[@]}"
    ;;
esac
