#!/usr/bin/env bash
set -euo pipefail

bids_root=$1  # adjust to dataset root

round() {
    # round to 3 decimals
    printf "%.3f" "$1"
}

for sub in $(find "$bids_root" -maxdepth 1 -type d -name "sub-*"); do
    dwi_dir="$sub/dwi"
    fmap_dir="$sub/fmap"
    [[ -d "$dwi_dir" && -d "$fmap_dir" ]] || continue

    for dwi_json in "$dwi_dir"/*_dwi.json; do
        [[ -f "$dwi_json" ]] || continue

        # determine dwi direction
        if [[ "$dwi_json" == *"dir-AP"* ]]; then
            fmap_dirlabel="PA"
        elif [[ "$dwi_json" == *"dir-PA"* ]]; then
            fmap_dirlabel="AP"
        else
            continue
        fi

        fmap_json=$(find "$fmap_dir" -name "*dir-${fmap_dirlabel}*_epi.json" | head -n 1)
        [[ -n "$fmap_json" ]] || continue

        # extract TotalReadoutTime (default 0 if missing)
        dwi_trt=$(jq -r '.TotalReadoutTime // 0' "$dwi_json")
        fmap_trt=$(jq -r '.TotalReadoutTime // 0' "$fmap_json")

        dwi_round=$(round "$dwi_trt")
        fmap_round=$(round "$fmap_trt")

        if [[ "$dwi_round" == "$fmap_round" ]]; then
            echo "✅ $sub: harmonizing TRT = $dwi_round"

            # rewrite both JSONs with harmonized TRT
            tmp=$(mktemp)
            jq --argjson t "$dwi_round" '.TotalReadoutTime = $t' "$dwi_json" > "$tmp" && mv "$tmp" "$dwi_json"
            jq --argjson t "$dwi_round" '.TotalReadoutTime = $t' "$fmap_json" > "$tmp" && mv "$tmp" "$fmap_json"
        else
            echo "⚠️ $sub: mismatch after rounding ($dwi_round vs $fmap_round)" >&2
        fi
    done
done
