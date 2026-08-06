#!/usr/bin/env bash
# faster-whisper X11 dictation helper for Cassiopeia
# Uses faster-whisper CLI + wtype for text injection.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/faster-whisper"
MODEL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/faster-whisper/models"
RECORDING_FLAG="$STATE_DIR/.recording"
AUDIO_FILE="$STATE_DIR/last-recording.wav"

mkdir -p "$STATE_DIR" "$MODEL_DIR"

# Use small.en model for speed; change to base.en / small.en / medium.en as needed
MODEL_NAME="${FASTER_WHISPER_MODEL:-small.en}"

toggle() {
  if [ -f "$RECORDING_FLAG" ]; then
    stop
  else
    start
  fi
}

start() {
  touch "$RECORDING_FLAG"
  echo "[faster-whisper] recording started (model=$MODEL_NAME)"
  # Record 5s chunks until stopped; simple one-shot approach
  # Use parecord or arecord; prefer parecord if pipewire-pulse is available
  if command -v parecord >/dev/null 2>&1; then
    parecord --file-format=wav --rate=16000 --channels=1 "$AUDIO_FILE" &
    RECORD_PID=$!
  elif command -v arecord >/dev/null 2>&1; then
    arecord -f cd -t wav -d 0 "$AUDIO_FILE" &
    RECORD_PID=$!
  else
    echo "no recorder found (parecord/arecord)" >&2
    rm -f "$RECORDING_FLAG"
    exit 1
  fi
  echo $RECORD_PID > "$STATE_DIR/.pid"
}

stop() {
  RECORD_PID=$(cat "$STATE_DIR/.pid" 2>/dev/null || echo "")
  if [ -n "$RECORD_PID" ]; then
    kill "$RECORD_PID" 2>/dev/null || true
    rm -f "$STATE_DIR/.pid"
  fi
  rm -f "$RECORDING_FLAG"
  echo "[faster-whisper] recording stopped, transcribing..."
  transcribe
}

transcribe() {
  if [ ! -f "$AUDIO_FILE" ]; then
    echo "no audio file" >&2
    exit 1
  fi
  MODEL_PATH="$MODEL_DIR/$MODEL_NAME"
  if [ ! -d "$MODEL_PATH" ]; then
    echo "[faster-whisper] downloading model $MODEL_NAME..."
    faster-whisper-ct2 --model-name "$MODEL_NAME" --output-dir "$MODEL_DIR" 2>/dev/null || true
  fi
  TEXT=$(faster-whisper --model "$MODEL_NAME" --language en "$AUDIO_FILE" 2>/dev/null | awk -F'\t' '{print $1}' | tr -d '\n' || echo "")
  if [ -n "$TEXT" ]; then
    echo "[faster-whisper] result: $TEXT"
    echo "$TEXT" | wtype -
  else
    echo "[faster-whisper] empty transcription" >&2
  fi
}

postprocess() {
  echo "[faster-whisper] post-process toggle not yet implemented"
}

cancel() {
  RECORD_PID=$(cat "$STATE_DIR/.pid" 2>/dev/null || echo "")
  if [ -n "$RECORD_PID" ]; then
    kill "$RECORD_PID" 2>/dev/null || true
    rm -f "$STATE_DIR/.pid"
  fi
  rm -f "$RECORDING_FLAG"
  echo "[faster-whisper] cancelled"
}

case "${1:-toggle}" in
  toggle) toggle ;;
  start) start ;;
  stop) stop ;;
  postprocess) postprocess ;;
  cancel) cancel ;;
  *) echo "usage: $0 {toggle|start|stop|postprocess|cancel}"; exit 1 ;;
esac
