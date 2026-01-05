#!/usr/bin/env bash
set -euo pipefail

# Usage: ./make_metrics_csv.sh /path/to/dataset output.csv
DATASET="$1"
OUTPUT="$2"

# Helper: extract mean, min, max from metric file
extract_stats() {
    local file="$1"
    if [ -f "$file" ]; then
        awk '
            $1 !~ /^#/ {
                mean=$1; min=$3; max=$4
                print mean "," min "," max
                exit
            }
        ' "$file"
    else
        echo "NA,NA,NA"
    fi
}

# Helper: extract single float (FA)
extract_scalar() {
    local file="$1"
    if [ -f "$file" ]; then
        awk '$1 !~ /^#/ { print $1; exit }' "$file"
    else
        echo "NA"
    fi
}

# CSV header
echo "subject_id,session_id,ad_mean,ad_min,ad_max,rd_mean,rd_min,rd_max,fa_1fiber,md_mean,md_min,md_max" > "$OUTPUT"

# Loop over subjects
for sub_dir in "$DATASET"/sub-*; do
    [ -d "$sub_dir" ] || continue
    subject_id=$(basename "$sub_dir")

    shopt -s nullglob
    sessions=("$sub_dir"/ses-*)
    shopt -u nullglob

    if [ ${#sessions[@]} -gt 0 ]; then
        # With sessions
        for ses_dir in "${sessions[@]}"; do
            [ -d "$ses_dir" ] || continue
            session_id=$(basename "$ses_dir")
            dwi_dir="$ses_dir/dwi"

            ad=$(extract_stats "$dwi_dir/${subject_id}_${session_id}_desc-ad_1fiber.txt")
            rd=$(extract_stats "$dwi_dir/${subject_id}_${session_id}_desc-rd_1fiber.txt")
            fa=$(extract_scalar "$dwi_dir/${subject_id}_${session_id}_desc-fa_1fiber.txt")
            md=$(extract_stats "$dwi_dir/${subject_id}_${session_id}_desc-md_ventricles.txt")

            echo "$subject_id,$session_id,$ad,$rd,$fa,$md" >> "$OUTPUT"
        done
    else
        # No sessions
        session_id=""
        dwi_dir="$sub_dir/dwi"

        ad=$(extract_stats "$dwi_dir/${subject_id}_desc-ad_1fiber.txt")
        rd=$(extract_stats "$dwi_dir/${subject_id}_desc-rd_1fiber.txt")
        fa=$(extract_scalar "$dwi_dir/${subject_id}_desc-fa_1fiber.txt")
        md=$(extract_stats "$dwi_dir/${subject_id}_desc-md_ventricles.txt")

        echo "$subject_id,$session_id,$ad,$rd,$fa,$md" >> "$OUTPUT"
    fi
done

echo "✅ CSV written to $OUTPUT"