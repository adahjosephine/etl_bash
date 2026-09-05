#!/bin/bash
#
# extract.sh
# Purpose: Downloads one or more raw CSV datasets defined by $CSV_URLS
#          (see .env) and saves each into the raw/ directory, confirming
#          success at every step.
#
# Author: Josephine Adah
# Part of: CoreDataEngineers ETL pipeline

# --- Strict mode: fail fast, fail loud ---
# -e : exit immediately if any command fails
# -u : treat undefined variables as errors
# -o pipefail : a pipeline fails if any command within it fails
set -euo pipefail

# --- Load configuration from .env ---
# .env contains CSV_URLS, the source URL(s) of the CSV dataset(s) to
# download. Kept out of version control (see .gitignore).
if [ -f .env ]; then
    source .env
else
    echo "ERROR: .env file not found. Cannot proceed without CSV_URLS."
    exit 1
fi

# --- Create the raw/ directory if it doesn't already exist ---
# -p flag means: don't error if it already exists (idempotent)
mkdir -p raw

echo "Starting extract stage..."

# --- Extract: download one or more CSVs listed in CSV_URLS ---
# CSV_URLS may contain a single URL or multiple space-separated URLs.
# Each file is saved using the convention: raw/<dataset-name>.csv
# Re-running the script for the same URL overwrites the same file
# (idempotent within a run; no historical dating is kept by design).
for URL in $CSV_URLS; do

    # Derive a clean dataset name from the URL's filename.
    # basename strips the path, leaving just the filename;
    # the second argument to basename strips the .csv extension;
    # tr converts hyphens to underscores for a cleaner name.
    RAW_NAME=$(basename "$URL" .csv | tr '-' '_')
    RAW_FILE="raw/${RAW_NAME}.csv"

    echo "Downloading: $URL"
    echo "Target file: $RAW_FILE"

    # curl flags:
    # -s : silent (no progress bar clutter)
    # -S : but show errors if they occur
    # -f : fail on HTTP errors (e.g. 404) instead of saving an error page
    # -L : follow redirects if the URL redirects elsewhere
    # -o : write output to this specific filename
    curl -sSfL -o "$RAW_FILE" "$URL"

    # --- Verification: confirm the download actually succeeded ---

    # Check 1: does the file exist?
    if [ -f "$RAW_FILE" ]; then
        echo "CONFIRMED: File exists at $RAW_FILE"
    else
        echo "ERROR: File was not created at $RAW_FILE"
        exit 1
    fi

    # Check 2: is the file non-empty? (-s tests "size greater than zero")
    if [ -s "$RAW_FILE" ]; then
        echo "CONFIRMED: File is non-empty."
    else
        echo "ERROR: File exists but is empty (0 bytes)."
        exit 1
    fi

    # Check 3: does it look like real CSV content, not an HTML error
    # page or something else the server returned unexpectedly?
    FIRST_LINE=$(head -n 1 "$RAW_FILE")
    if [[ "$FIRST_LINE" == *","* ]]; then
        echo "CONFIRMED: File appears to be valid CSV."
    else
        echo "ERROR: File does not look like a valid CSV."
        echo "First line found: $FIRST_LINE"
        file "$RAW_FILE"
        exit 1
    fi

    echo "Finished processing: $RAW_FILE"
    echo "---"

done

echo "Extract stage complete."