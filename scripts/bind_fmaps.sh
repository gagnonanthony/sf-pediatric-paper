#!/usr/bin/env bash
set -euo pipefail

bids_root=$1 # change to your dataset root

for sub in $(find "$bids_root" -maxdepth 1 -type d -name "sub-*"); do
    dwi_dir="$sub/dwi"
    fmap_dir="$sub/fmap"

    # Skip if no DWI or fmap
    [[ -d "$dwi_dir" && -d "$fmap_dir" ]] || continue

    # Find first DWI file (assuming one run)
    dwi_file=$(find "$dwi_dir" -name "*dwi.nii.gz" | head -n 1)
    [[ -n "$dwi_file" ]] || continue

    # Extract phase direction from filename (AP or PA)
    if [[ "$dwi_file" == *"dir-AP"* ]]; then
        dwi_dirlabel="AP"
        fmap_dirlabel="PA"
    elif [[ "$dwi_file" == *"dir-PA"* ]]; then
        dwi_dirlabel="PA"
        fmap_dirlabel="AP"
    else
        echo "⚠️ Could not detect direction for $dwi_file" >&2
        continue
    fi

    # Find fmap JSON with the opposite direction
    fmap_json=$(find "$fmap_dir" -name "*dir-${fmap_dirlabel}*_epi.json" | head -n 1)
    [[ -n "$fmap_json" ]] || { echo "⚠️ No fmap for $sub with dir-${fmap_dirlabel}" >&2; continue; }

    # Path relative to subject root (BIDS requires relative)
    intended_path="${dwi_file#$sub/}"

    echo "✅ Updating $fmap_json → IntendedFor: $intended_path"

    # Update JSON (overwrite)
    tmp=$(mktemp)
    jq --arg f "$intended_path" '.IntendedFor = [$f]' "$fmap_json" > "$tmp" && mv "$tmp" "$fmap_json"
done
