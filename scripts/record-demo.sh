#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/GrokDesk.app"
RECORDINGS_DIR="$ROOT_DIR/dist/demo-recordings"
TIMESTAMP="$(/bin/date '+%Y%m%d-%H%M%S')"
STATE_ROOT="/Users/Shared/GrokDesk-Recording-$TIMESTAMP"
MOV_PATH="$RECORDINGS_DIR/GrokDesk-demo-$TIMESTAMP.mov"
DISPLAY_NUMBER=""
DURATION=""
COUNTDOWN=3
CREATE_GIF=0
PREPARE_ONLY=0

usage() {
  cat <<'EOF'
Usage: ./scripts/record-demo.sh [options]

Launch GrokDesk with a fresh, isolated demo profile and record a safe demo.
The normal GrokDesk profile and Grok Build sessions are never modified.

Options:
  --app PATH          GrokDesk.app to launch (default: dist/GrokDesk.app)
  --output PATH       Output .mov path
  --profile PATH      Isolated demo state directory
  --display NUMBER    Record a display directly (1 = main, 2 = secondary)
  --duration SECONDS  Stop automatically after this many seconds
  --countdown SECONDS Countdown before direct display recording (default: 3)
  --gif               Also create an optimized GIF (requires ffmpeg)
  --prepare-only      Launch the isolated demo app without starting recording
  -h, --help          Show this help

Without --display, macOS presents its recording toolbar so you can select a
window, an area, or the monitor where GrokDesk is currently displayed.
EOF
}

require_value() {
  if [[ $# -lt 2 || -z "$2" ]]; then
    echo "Missing value for $1" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      require_value "$@"
      APP_BUNDLE="$2"
      shift 2
      ;;
    --output)
      require_value "$@"
      MOV_PATH="$2"
      shift 2
      ;;
    --profile)
      require_value "$@"
      STATE_ROOT="$2"
      shift 2
      ;;
    --display)
      require_value "$@"
      DISPLAY_NUMBER="$2"
      shift 2
      ;;
    --duration)
      require_value "$@"
      DURATION="$2"
      shift 2
      ;;
    --countdown)
      require_value "$@"
      COUNTDOWN="$2"
      shift 2
      ;;
    --gif)
      CREATE_GIF=1
      shift
      ;;
    --prepare-only)
      PREPARE_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$APP_BUNDLE" || ! -x "$APP_BUNDLE/Contents/MacOS/GrokDesk" ]]; then
  echo "GrokDesk.app was not found at: $APP_BUNDLE" >&2
  echo "Package it first with ./scripts/package-app.sh" >&2
  exit 1
fi

for numeric_value in "$DISPLAY_NUMBER" "$DURATION" "$COUNTDOWN"; do
  if [[ -n "$numeric_value" && ! "$numeric_value" =~ ^[0-9]+$ ]]; then
    echo "Display, duration, and countdown values must be non-negative integers." >&2
    exit 2
  fi
done

/bin/mkdir -p "$STATE_ROOT" "$(/usr/bin/dirname "$MOV_PATH")"

environment_is_set=0
clear_launch_environment() {
  if [[ "$environment_is_set" -eq 1 ]]; then
    /bin/launchctl unsetenv GROKDESK_STATE_ROOT >/dev/null 2>&1 || true
    /bin/launchctl unsetenv GROKDESK_SKIP_SESSION_IMPORT >/dev/null 2>&1 || true
    environment_is_set=0
  fi
}
trap clear_launch_environment EXIT INT TERM

# Launch Services does not inherit this shell's environment. Set the two
# narrowly scoped variables only long enough for the new app process to start.
/bin/launchctl setenv GROKDESK_STATE_ROOT "$STATE_ROOT"
/bin/launchctl setenv GROKDESK_SKIP_SESSION_IMPORT "1"
environment_is_set=1
/usr/bin/open -n "$APP_BUNDLE"
/bin/sleep 2
clear_launch_environment

echo
echo "GrokDesk demo profile: $STATE_ROOT"
echo "Normal GrokDesk sessions are not imported or modified."
echo "The fresh profile starts at the language selection screen."

if [[ "$PREPARE_ONLY" -eq 1 ]]; then
  echo "Demo app launched. Recording was not started (--prepare-only)."
  exit 0
fi

if [[ -n "$DISPLAY_NUMBER" ]]; then
  if [[ "$COUNTDOWN" -gt 0 ]]; then
    echo "Recording display $DISPLAY_NUMBER in:"
    for ((remaining = COUNTDOWN; remaining > 0; remaining--)); do
      echo "  $remaining"
      /bin/sleep 1
    done
  fi
else
  echo
  echo "Select the GrokDesk window, recording area, or target monitor in the"
  echo "macOS recording toolbar, then click Record."
fi

capture_args=(-v -k)
if [[ -n "$DISPLAY_NUMBER" ]]; then
  capture_args+=("-D$DISPLAY_NUMBER")
else
  capture_args+=(-U -Jvideo)
fi
if [[ -n "$DURATION" ]]; then
  capture_args+=("-V$DURATION")
fi

echo "Recording to: $MOV_PATH"
/usr/sbin/screencapture "${capture_args[@]}" "$MOV_PATH"

if [[ ! -s "$MOV_PATH" ]]; then
  echo "No recording was created. The macOS recording may have been cancelled." >&2
  exit 1
fi

echo "Video created: $MOV_PATH"

if [[ "$CREATE_GIF" -eq 1 ]]; then
  if ! FFMPEG_BIN="$(/usr/bin/which ffmpeg 2>/dev/null)"; then
    echo "Video is ready, but GIF conversion requires ffmpeg." >&2
    echo "Install it with: brew install ffmpeg" >&2
    exit 1
  fi

  GIF_PATH="${MOV_PATH%.*}.gif"
  "$FFMPEG_BIN" -hide_banner -loglevel error -y \
    -i "$MOV_PATH" \
    -filter_complex \
    "fps=12,scale='min(1280,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=bayer" \
    "$GIF_PATH"
  echo "GIF created: $GIF_PATH"
fi

echo
echo "The isolated profile is intentionally retained for review:"
echo "  $STATE_ROOT"
echo "Delete that exact directory manually after you no longer need the demo."
