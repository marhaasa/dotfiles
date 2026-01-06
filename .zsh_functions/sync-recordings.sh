#!/usr/bin/env bash

# CHANGE THESE for where to rsync from and to
SOURCE_DIR="${HOME}/Library/Containers/engineering.teenage.fieldkit/Data/Documents/TP-7 MTP Device-F1RWE11G/"
DEST_DIR="${NOTES}/0-inbox"

# Whisper model to use (downloaded automatically from HuggingFace)
MODEL="mlx-community/whisper-large-v3-mlx"

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

  synced_files=$(rsync -avhz --itemize-changes "${SOURCE_DIR}" "${DEST_DIR}" |
    grep -E '^>f' |
    sed 's/^>f[^\s]* //')

  # Process only the synced files
  for file in $synced_files; do
    if [[ "$file" == *.wav ]]; then
      local file_path="${DEST_DIR}/${file}"
      printf "\nProcessing: %s\n" "$file_path"
      _normalize_and_transcribe "$file_path"
    fi
  done
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

  # Normalize volume
  ffmpeg -hide_banner -loglevel warning -y -i "$file" -af loudnorm "$normalized_file"

  # Transcribe with mlx-whisper (quiet mode)
  mlx_whisper "$normalized_file" \
    --model "$MODEL" \
    --language no \
    --verbose False \
    -f txt \
    --output-name "${file_dirname}/${file_basename}"

  # Clean up normalized file
  rm "$normalized_file"

  # Check if transcription has content
  if [ ! -s "${txt_file}" ]; then
    printf "No dialog found. Removing empty transcription file: %s\n" "$txt_file"
    rm "${txt_file}"
    return
  fi

  # Convert to markdown with frontmatter
  {
    echo "---"
    echo "source: ${file_basename}.wav"
    echo "date: ${recording_date}"
    echo "type: voice-memo"
    echo "---"
    echo ""
    cat "$txt_file"
  } > "$md_file"

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
    echo "[[${note_name}]]" >> "$daily_note"
    printf "Linked to daily note: %s\n" "$daily_note"
  else
    printf "Warning: Could not create daily note: %s\n" "$daily_note"
  fi
}

# Call `_main` after everything has been defined.
_main "$@"
