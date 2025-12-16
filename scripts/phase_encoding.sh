#!/usr/bin/env bash
set -euo pipefail

bids_root=$1 # change to your dataset root

for dwi_json in $(find "$bids_root" -type f -name "*_dwi.json"); do
    # Skip if already has PhaseEncodingDirection
    if jq -e 'has("PhaseEncodingDirection")' "$dwi_json" >/dev/null; then
        echo "✅ $dwi_json already has PhaseEncodingDirection"
        continue
    fi

    # Decide direction from filename
    if [[ "$dwi_json" == *"dir-AP"* ]]; then
        direction="j-"
    elif [[ "$dwi_json" == *"dir-PA"* ]]; then
        direction="j"
    else
        echo "⚠️ Cannot determine PhaseEncodingDirection for $dwi_json" >&2
        continue
    fi

    echo "➕ Adding PhaseEncodingDirection=$direction to $dwi_json"

    tmp=$(mktemp)
    jq --arg dir "$direction" '. + {PhaseEncodingDirection: $dir}' "$dwi_json" > "$tmp" && mv "$tmp" "$dwi_json"
done
