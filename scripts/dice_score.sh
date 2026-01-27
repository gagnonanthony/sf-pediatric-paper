#!/bin/bash

# Usage: ./dice_score.sh <input_folder> <output_folder> <container> [n_jobs]
# Example: ./dice_score.sh nf-pediatric-0.2.0 output /path/to/container.sif 4

input_folder=$1
output_folder=$2
container=$3
n_jobs=${4:-1}  # Default to 1 job if not specified

# Validate inputs
if [ -z "$input_folder" ] || [ -z "$output_folder" ] || [ -z "$container" ]; then
    echo "Error: Missing arguments"
    echo "Usage: $0 <input_folder> <output_folder> <container> [n_jobs]"
    exit 1
fi

# Create output directory
mkdir -p "$output_folder"

# Test/retest pairs
pairs=("test1:retest1" "test2:retest2")

# Hemispheres
hemispheres=("left" "right")

# Log file
log_file="$output_folder/comparison_log.txt"
echo "Starting pairwise comparison - $(date)" > "$log_file"
echo "Input folder: $input_folder" >> "$log_file"
echo "Output folder: $output_folder" >> "$log_file"
echo "Container: $container" >> "$log_file"
echo "Number of parallel jobs: $n_jobs" >> "$log_file"
echo "" >> "$log_file"

# Function to run a single comparison
run_comparison() {
    local subject=$1
    local test_session=$2
    local retest_session=$3
    local hemi=$4
    local input_folder=$5
    local output_folder=$6
    local container=$7
    
    # Construct file paths
    local test_file="$input_folder/$subject/ses-$test_session/dwi/bundles/${subject}_ses-${test_session}_space-MNIPediatricAsym_tract-PyramidalTract_hemi-${hemi}_track-sdstream_tractogram.trk"
    local retest_file="$input_folder/$subject/ses-$retest_session/dwi/bundles/${subject}_ses-${retest_session}_space-MNIPediatricAsym_tract-PyramidalTract_hemi-${hemi}_track-sdstream_tractogram.trk"
    
    # Check if files exist
    if [ ! -f "$test_file" ]; then
        echo "SKIP: $subject ses-$test_session/$retest_session hemi-$hemi - test file not found"
        return 1
    fi
    if [ ! -f "$retest_file" ]; then
        echo "SKIP: $subject ses-$test_session/$retest_session hemi-$hemi - retest file not found"
        return 1
    fi
    
    # Create output filename
    local output_json="$output_folder/${subject}_test${test_session#test}_retest${retest_session#retest}_PyramidalTract_hemi-${hemi}_comparison.json"
    
    # Run comparison
    if apptainer run "$container" scil_bundle_pairwise_comparison \
        "$test_file" \
        "$retest_file" \
        "$output_json" \
        --streamline_dice \
        --keep_tmp \
        -v ERROR 2>&1; then
        echo "SUCCESS: $subject test${test_session#test}/retest${retest_session#retest} hemi-$hemi"
        return 0
    else
        echo "FAILED: $subject test${test_session#test}/retest${retest_session#retest} hemi-$hemi"
        return 1
    fi
}

# Export function and variables for parallel
export -f run_comparison
export input_folder output_folder container

# Create jobs list
jobs_file="$output_folder/jobs_list.txt"
> "$jobs_file"

echo "Scanning for subjects and generating job list..." | tee -a "$log_file"

# Generate all jobs
for subject_dir in "$input_folder"/sub-*; do
    if [ ! -d "$subject_dir" ]; then
        continue
    fi
    
    subject=$(basename "$subject_dir")
    
    # Check each test/retest pair
    for pair in "${pairs[@]}"; do
        test_session="${pair%%:*}"
        retest_session="${pair##*:}"
        
        # Check if both sessions exist
        test_dir="$input_folder/$subject/ses-$test_session"
        retest_dir="$input_folder/$subject/ses-$retest_session"
        
        if [ -d "$test_dir" ] && [ -d "$retest_dir" ]; then
            # Add jobs for both hemispheres
            for hemi in "${hemispheres[@]}"; do
                echo "$subject $test_session $retest_session $hemi $input_folder $output_folder $container" >> "$jobs_file"
            done
        fi
    done
done

total_jobs=$(wc -l < "$jobs_file")
echo "Found $total_jobs comparisons to perform" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Run jobs in parallel
echo "Running comparisons with $n_jobs parallel jobs..." | tee -a "$log_file"
echo "" | tee -a "$log_file"

cat "$jobs_file" | parallel --colsep ' ' -j "$n_jobs" --bar run_comparison {1} {2} {3} {4} {5} {6} {7} 2>&1 | tee -a "$log_file"

# Count results
successful_comparisons=$(grep -c "^SUCCESS:" "$log_file" || echo 0)
failed_comparisons=$(grep -c "^FAILED:" "$log_file" || echo 0)
skipped_comparisons=$(grep -c "^SKIP:" "$log_file" || echo 0)

# Summary
echo "" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"
echo "Comparison Summary" | tee -a "$log_file"
echo "======================================" | tee -a "$log_file"
echo "Total jobs: $total_jobs" | tee -a "$log_file"
echo "Successful: $successful_comparisons" | tee -a "$log_file"
echo "Failed: $failed_comparisons" | tee -a "$log_file"
echo "Skipped: $skipped_comparisons" | tee -a "$log_file"
echo "Completed at: $(date)" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "Results saved to: $output_folder"
echo "Log file: $log_file"