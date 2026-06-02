import subprocess
import argparse

import pandas as pd
from tqdm import tqdm


def argument_parser():
    parser = argparse.ArgumentParser(
        description="Correct exaggerated memory entries in Nextflow trace files using SLURM accounting logs."
    )
    parser.add_argument(
        "trace_file",
        help="Path to the Nextflow trace file (tab-delimited).",
    )
    parser.add_argument(
        "--output_file",
        default="trace_corrected.txt",
        help="Path to save the corrected trace file (default: trace_corrected.txt).",
    )
    return parser.parse_args()


def get_real_slurm_memory(job_id):
    """Queries the SLURM database for the true maximum physical memory (MaxRSS)"""
    if not job_id or pd.isna(job_id) or str(job_id).strip() in ["", "-"]:
        return None
    try:
        # Requesting MaxRSS and MaxVMSize specifically for the batch/primary step
        cmd = f"sacct -j {int(float(job_id))} -P -n --format=MaxRSS,MaxVMSize"
        result = subprocess.check_output(cmd, shell=True, text=True).strip()
        
        if not result:
            return None
        
        # SLURM may return multiple lines (job, batch step, extern step). 
        # We parse the maximum found across steps.
        max_rss_kb = 0
        max_vmem_kb = 0
        
        for line in result.split("\n"):
            parts = line.split("|")
            if len(parts) >= 2:
                rss_str, vmem_str = parts[0].strip(), parts[1].strip()
                print(f"Debug: SLURM output for job_id {job_id} - MaxRSS: {rss_str}, MaxVMSize: {vmem_str}")
                
                # Convert SLURM units (e.g., 4194304K, 4G, 4096M) to plain text representation
                for val_str, is_rss in [(rss_str, True), (vmem_str, False)]:
                    if not val_str or val_str == "0":
                        continue
                    
                    # Convert to Kilobytes
                    factor = 1
                    if val_str.endswith('K'): 
                        val_str = val_str[:-1]
                    elif val_str.endswith('M'): 
                        val_str, factor = val_str[:-1], 1024
                    elif val_str.endswith('G'): 
                        val_str, factor = val_str[:-1], 1024 * 1024
                    elif val_str.endswith('T'): 
                        val_str, factor = val_str[:-1], 1024 * 1024 * 1024
                        
                    try:
                        kb_val = float(val_str) * factor
                        if is_rss:
                            max_rss_kb = max(max_rss_kb, kb_val)
                        else:
                            max_vmem_kb = max(max_vmem_kb, kb_val)
                    except ValueError:
                        pass
                        
        return max_rss_kb, max_vmem_kb
    except Exception as e:
        print(f"Warning: Could not retrieve SLURM data for job_id {job_id}. Error: {str(e)}")
        return None


def main():
    args = argument_parser()
    # Load the exaggerated Nextflow trace file (tab-separated)
    df = pd.read_csv(args.trace_file, sep="\t")

    print("Correcting exaggerated memory entries via SLURM accounting logs...")
    for idx, row in tqdm(df.iterrows(), total=len(df)):
        # Check if this task belongs to your problematic python process block
        # (Optional: remove this if-statement if you want to fix ALL tasks)
        slurm_data = get_real_slurm_memory(row['native_id'])
        
        if slurm_data:
            real_rss_kb, real_vmem_kb = slurm_data
            
            if real_rss_kb > 0:
                # Convert back to standard Nextflow formatting (e.g., "4.2 GB")
                if real_rss_kb > 1024 * 1024:
                    df.at[idx, 'rss'] = f"{round(real_rss_kb / (1024*1024), 1)} GB"
                else:
                    df.at[idx, 'rss'] = f"{round(real_rss_kb / 1024, 1)} MB"
                    
            if real_vmem_kb > 0:
                if real_vmem_kb > 1024 * 1024:
                    df.at[idx, 'vmem'] = f"{round(real_vmem_kb / (1024*1024), 1)} GB"
                else:
                    df.at[idx, 'vmem'] = f"{round(real_vmem_kb / 1024, 1)} MB"

    # Save the cleansed benchmarking dataset
    df.to_csv(args.output_file, sep="\t", index=False)
    print("Done! Cleaned benchmarking metrics saved to {}".format(args.output_file))


if __name__ == "__main__":
    main()
