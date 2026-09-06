#!/bin/bash
#
# move_files.sh
# Purpose: Moves all CSV and JSON files from a source folder into a
#          destination folder called json_and_CSV, confirming success.
#          Works with one or more files of either type.
#
# Author: Josephine Adah
# Part of: CoreDataEngineers ETL pipeline

set -euo pipefail

# --- Define source and destination folders ---
SOURCE_DIR="incoming"
DEST_DIR="json_and_CSV"

# --- Create the destination folder if it doesn't already exist ---
mkdir -p "$DEST_DIR"

echo "Starting file move..."

# --- Move all matching files ---
# The nullglob option prevents literal "*.csv" from being treated as
# a filename if no matching files exist (safer than the default Bash
# behavior, which would try to "move" a non-existent literal pattern).
shopt -s nullglob

FILES_TO_MOVE=("$SOURCE_DIR"/*.csv "$SOURCE_DIR"/*.json)

if [ ${#FILES_TO_MOVE[@]} -eq 0 ]; then
    echo "No CSV or JSON files found in $SOURCE_DIR. Nothing to move."
    exit 0
fi

for FILE in "${FILES_TO_MOVE[@]}"; do
    echo "Moving: $FILE"
    mv "$FILE" "$DEST_DIR/"

    FILENAME=$(basename "$FILE")
    if [ -f "$DEST_DIR/$FILENAME" ]; then
        echo "CONFIRMED: $FILENAME is now in $DEST_DIR/"
    else
        echo "ERROR: $FILENAME was not found in $DEST_DIR/ after move."
        exit 1
    fi
done

echo "File move complete."