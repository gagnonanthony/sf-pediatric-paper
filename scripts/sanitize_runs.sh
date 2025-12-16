#!/usr/bin/env bash
set -euo pipefail

# Usage: ./select_run.sh sub-P0189 01
SUBJECT_DIR=$1
RUN_KEEP=$2

DWI_DIR="${SUBJECT_DIR}/dwi"

# Loop through all runs in dwi/
for f in "${DWI_DIR}"/*_run-*_dwi.*; do
    if [[ "$f" == *"_run-${RUN_KEEP}_"* ]]; then
        # File to keep → rename (remove _run-XX)
        new_name="${f/_run-${RUN_KEEP}/}"
        mv "$f" "$new_name"
    else
        # File to delete
        rm "$f"
    fi
done
