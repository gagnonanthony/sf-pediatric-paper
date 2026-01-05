#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_priors_all.sh /path/to/derivatives NUM_CORES
# Example: ./run_priors_all.sh ~/projects/derivatives 8

# Path to your container
CONTAINER=~/projects/def-larissa1/containers/scilus-scilpy-2.2.1_cpu.img

# Root of your BIDS derivatives dataset
DERIVS=$1
CORES=$2

# Find all subjects (sub-XXXX directories under derivatives)
subjects=$(find "$DERIVS" -mindepth 1 -maxdepth 1 -type d -name "sub-*")

# Function to run priors for a subject or session
run_priors() {
    subj_or_sesdir=$1
    base=$(basename "$subj_or_sesdir")

    # Determine if this is a session folder or just a subject folder
    if [[ "$base" == ses-* ]]; then
        # Session folder
        sesdir="$subj_or_sesdir"
        sub=$(basename "$(dirname "$sesdir")")
        ses="$base"
        prefix="${sub}_${ses}"
    else
        # Subject folder without sessions
        sub="$base"
        sesdir="$subj_or_sesdir"
        ses=""
        prefix="$sub"
    fi

    dwi_dir="$sesdir/dwi"
    fa="${dwi_dir}/${prefix}_desc-fa.nii.gz"
    ad="${dwi_dir}/${prefix}_desc-ad.nii.gz"
    rd="${dwi_dir}/${prefix}_desc-rd.nii.gz"
    md="${dwi_dir}/${prefix}_desc-md.nii.gz"

    # Output files
    out_ad="${dwi_dir}/${prefix}_desc-ad_1fiber.txt"
    out_rd="${dwi_dir}/${prefix}_desc-rd_1fiber.txt"
    out_mask_1fiber="${dwi_dir}/${prefix}_desc-1fiber_mask.nii.gz"
    out_md="${dwi_dir}/${prefix}_desc-md_ventricles.txt"
    out_mask_vent="${dwi_dir}/${prefix}_desc-ventricles_mask.nii.gz"
    out_fa_mean="${dwi_dir}/${prefix}_desc-fa_1fiber.txt"

    echo "Running priors for ${prefix}..."

    # Run priors
    scil_NODDI_priors \
        "$fa" "$ad" "$rd" "$md" \
        --fa_min_single_fiber 0.65 \
        --md_min_ventricle 0.002 \
        --out_txt_1fiber_para "$out_ad" \
        --out_txt_1fiber_perp "$out_rd" \
        --out_mask_1fiber "$out_mask_1fiber" \
        --out_txt_ventricles "$out_md" \
        --out_mask_ventricles "$out_mask_vent" \
        -f

    # Run FA stats inside 1fiber mask and extract mean value
    fa_mean=$(scil_volume_stats_in_ROI "$out_mask_1fiber" --metrics "$fa" \
        | sed -n '/^{/,/^}/p' \
        | jq -r '.[].mean')

    echo "$fa_mean" > "$out_fa_mean"
}

export -f run_priors
export CONTAINER

# Build a list of all session directories (if exist) and subjects without sessions
tasks=()
for sub_dir in $subjects; do
    ses_dirs=("$sub_dir"/ses-*)
    if [ -d "${ses_dirs[0]}" ]; then
        # Subject has sessions
        for ses_dir in "${ses_dirs[@]}"; do
            [ -d "$ses_dir" ] || continue
            tasks+=("$ses_dir")
        done
    else
        # Subject has no sessions
        tasks+=("$sub_dir")
    fi
done

# Run in parallel
parallel --will-cite -j "$CORES" --bar run_priors ::: "${tasks[@]}"

echo "✅ All priors completed."