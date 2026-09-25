#!/usr/bin/env bash

# CHANGE THESE for where to rsync from and to
SOURCE_DIR="${HOME}/Library/Containers/engineering.teenage.fieldkit/Data/Documents/TP-7 MTP Device-F1RYD136/"
DEST_DIR="${NOTES}/0-inbox"

# Whisper model to use (downloaded automatically from HuggingFace)
MODEL="mlx-community/whisper-large-v3-mlx"

# HuggingFace token for pyannote (required for diarization)
# Set HF_TOKEN environment variable to enable speaker detection
HF_TOKEN="${HF_TOKEN:-}"

# Don't allow unset variables
set -o nounset

# Exit immediately if a pipeline returns non-zero.
set -o errexit
# Give helpful error message if that happens
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR
# Allow the above trap be inherited by all functions in the script.
set -o errtrace

# Return value of a pipeline is the value of the last (rightmost) command to
# exit with a non-zero status, or zero if all commands in the pipeline exit
# successfully.
set -o pipefail

# Set $IFS to only newline and tab.
#
# http://www.dwheeler.com/essays/filenames-in-shell.html
IFS=$'\n\t'

###############################################################################
# Check dependencies
###############################################################################
check_dependencies() {
  local deps=(rsync ffmpeg mlx_whisper grep sed)
  local missing_deps=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Error: The following required dependencies are missing:" "${missing_deps[@]}"
    echo ""
    echo "Install mlx-whisper with: pip install mlx-whisper"
    exit 1
  fi
}

# Check if whisperx is available for diarization
check_diarization_deps() {
  if ! ~/.venvs/whisperx/bin/python3 -c "import whisperx" 2>/dev/null; then
    return 1
  fi
  if [[ -z "$HF_TOKEN" ]]; then
    return 1
  fi
  return 0
}

# Transcribe with automatic speaker detection using whisperX
# Returns exit code 0 if multiple speakers, 1 if single speaker
transcribe_with_diarization() {
  local audio_file="$1"
  local output_file="$2"

  ~/.venvs/whisperx/bin/python3 <<PYTHON_SCRIPT
import whisperx
import torch
import sys

audio_file = "${audio_file}"
output_file = "${output_file}"
hf_token = "${HF_TOKEN}"

device = "mps" if torch.backends.mps.is_available() else "cpu"
compute_type = "float32"

# Load and transcribe (faster-whisper/ctranslate2 does not support MPS, must use cpu)
model = whisperx.load_model("large-v3", "cpu", compute_type=compute_type)
audio = whisperx.load_audio(audio_file)
result = model.transcribe(audio, batch_size=16)

detected_language = result["language"]
print(f"Detected language: {detected_language}")

# Align whisper output
model_a, metadata = whisperx.load_align_model(language_code=detected_language, device=device)
result = whisperx.align(result["segments"], model_a, metadata, audio, device, return_char_alignments=False)

# Diarize
diarize_model = whisperx.diarize.DiarizationPipeline(token=hf_token, device=device)
diarize_segments = diarize_model(audio)
result = whisperx.assign_word_speakers(diarize_segments, result)

# Count unique speakers
speakers = set()
for segment in result["segments"]:
    speaker = segment.get("speaker")
    if speaker:
        speakers.add(speaker)

num_speakers = len(speakers)
print(f"Detected {num_speakers} speaker(s)")

# Format output based on speaker count
if num_speakers > 1:
    # Multiple speakers: format as script with speaker labels
    current_speaker = None
    lines = []

    for segment in result["segments"]:
        speaker = segment.get("speaker", "UNKNOWN")
        text = segment["text"].strip()

        if speaker != current_speaker:
            current_speaker = speaker
            lines.append(f"\n**{speaker}**")

        lines.append(text)

    with open(output_file, "w") as f:
        f.write("\n".join(lines).strip())
else:
    # Single speaker: plain text output
    lines = [segment["text"].strip() for segment in result["segments"]]
    with open(output_file, "w") as f:
        f.write(" ".join(lines))

# Exit with code indicating multi-speaker (for frontmatter type)
sys.exit(0 if num_speakers > 1 else 1)
PYTHON_SCRIPT
}

# Check dependencies and exit with error if any are missing
check_dependencies

###############################################################################
# Main
###############################################################################

_main() {
  local synced_files
  echo "Syncing missing files from ${SOURCE_DIR} to ${DEST_DIR}..."

  # Ensure destination directory exists
  mkdir -p "${DEST_DIR}"

  synced_files=$(rsync -avhz --itemize-changes --exclude="._*" "${SOURCE_DIR}" "${DEST_DIR}" |
    grep -E '^>f' |
    sed 's/^>f[^\s]* //')

  # Process all WAV files in DEST_DIR that haven't been transcribed yet
  while IFS= read -r -d '' file_path <&3; do
    local file_basename file_dirname note_prefix
    file_basename=$(basename "${file_path}" .wav)
    file_dirname=$(dirname "${file_path}")
    note_prefix=$(echo "$file_basename" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{6})_[0-9]+$/\1-\2/')

    # Skip files that don't match the expected naming pattern
    if [[ "$note_prefix" == "$file_basename" ]]; then
      continue
    fi

    # Skip if already transcribed (md file exists)
    if ls "${file_dirname}/${note_prefix}-"*.md 2>/dev/null | grep -q .; then
      continue
    fi

    printf "\nProcessing: %s\n" "$file_path"
    _normalize_and_transcribe "$file_path"
  done 3< <(find "${DEST_DIR}" -name "*.wav" -not -name "._*" -print0)
}

_normalize_and_transcribe() {
  local file="$1"
  local file_basename
  file_basename=$(basename "${file}" .wav)
  local file_dirname
  file_dirname=$(dirname "${file}")

  # Convert filename from 2026-01-06_085421_000 to 2026-01-06-085421-memo
  local note_name
  note_name=$(echo "$file_basename" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{6})_[0-9]+$/\1-\2-memo/')

  local normalized_file="${file_dirname}/${file_basename}_normalized.wav"
  local txt_file="${file_dirname}/${file_basename}.txt"
  local md_file="${file_dirname}/${note_name}.md"
  local recording_date
  recording_date=$(date -r "$file" "+%Y-%m-%d")
  local memo_type="voice-memo"
  local multi_speaker=false

  # Normalize volume
  ffmpeg -hide_banner -loglevel warning -y -i "$file" -af loudnorm "$normalized_file"

  # Try diarization if available, otherwise fall back to mlx-whisper
  if check_diarization_deps; then
    printf "Using whisperX with speaker detection...\n"
    if transcribe_with_diarization "$normalized_file" "$txt_file"; then
      multi_speaker=true
      memo_type="conversation"
      # Update note name for conversations
      note_name=$(echo "$file_basename" | sed -E 's/^([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{6})_[0-9]+$/\1-\2-conversation/')
      md_file="${file_dirname}/${note_name}.md"
    fi
  else
    printf "Using mlx-whisper (set HF_TOKEN for speaker detection)...\n"
    mlx_whisper "$normalized_file" \
      --model "$MODEL" \
      --verbose False \
      -f txt \
      --output-name "${file_dirname}/${file_basename}"
  fi

  # Clean up normalized file
  rm "$normalized_file"

  # Check if transcription has content
  if [ ! -s "${txt_file}" ]; then
    printf "No dialog found. Removing empty transcription file: %s\n" "$txt_file"
    rm -f "${txt_file}"
    return
  fi

  # Convert to markdown with frontmatter
  {
    echo "---"
    echo "source: ${file_basename}.wav"
    echo "date: ${recording_date}"
    echo "type: ${memo_type}"
    if $multi_speaker; then
      echo "speakers: multiple"
    fi
    echo "---"
    echo ""
    cat "$txt_file"
  } >"$md_file"

  # Remove the txt file
  rm "$txt_file"

  printf "Created: %s\n" "$md_file"

  # Link to today's daily note
  _link_to_daily_note "$note_name"
}

_link_to_daily_note() {
  local note_name="$1"
  local today
  today=$(date "+%Y-%m-%d")
  local daily_note="${NOTES}/periodic-notes/daily-notes/${today}.md"

  # Create daily note if it doesn't exist
  if [ ! -f "$daily_note" ]; then
    if command -v scribe >/dev/null 2>&1; then
      printf "Creating daily note with scribe...\n"
      scribe daily --no-edit
    fi
  fi

  # Append link to daily note if it exists
  if [ -f "$daily_note" ]; then
    echo "[[${note_name}]]" >>"$daily_note"
    printf "Linked to daily note: %s\n" "$daily_note"
  else
    printf "Warning: Could not create daily note: %s\n" "$daily_note"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
