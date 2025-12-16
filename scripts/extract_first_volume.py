#!/usr/bin/env python3
import nibabel as nib
import numpy as np
import argparse


def remove_first_volume(dwi_file, bval_file, bvec_file, out_prefix, dir_orig, dir_new):
    # --- Load DWI ---
    img = nib.load(dwi_file)
    data = img.get_fdata()
    affine = img.affine
    header = img.header

    # Remove first volume
    first_vol = data[..., 0]
    new_data = data[..., 1:]

    # Save first image.
    first_img = nib.Nifti1Image(first_vol, affine, header)
    nib.save(first_img, f"{out_prefix}/fmap/{out_prefix}_dir-{dir_new}_epi.nii.gz")

    # Save new DWI
    new_img = nib.Nifti1Image(new_data, affine, header)
    nib.save(new_img, f"{out_prefix}/dwi/{out_prefix}_dir-{dir_orig}_dwi.nii.gz")

    # --- Load bvals/bvecs ---
    bvals = np.loadtxt(bval_file)
    bvecs = np.loadtxt(bvec_file)

    # Remove first entry
    new_bvals = bvals[1:]
    new_bvecs = bvecs[:, 1:] if bvecs.ndim > 1 else bvecs[1:]

    # Add a small check to ensure the length of the bvals and bvecs match the new data.
    if len(new_bvals) != new_data.shape[-1]:
        raise ValueError("Mismatch between number of volumes in DWI and bvals/bvecs.")
    if new_bvecs.shape[1] != new_data.shape[-1]:
        raise ValueError("Mismatch between number of volumes in DWI and bvecs.")

    # Save updated bvals/bvecs
    np.savetxt(f"{out_prefix}/dwi/{out_prefix}_dir-{dir_orig}_dwi.bval", new_bvals, fmt="%.6f")
    np.savetxt(f"{out_prefix}/dwi/{out_prefix}_dir-{dir_orig}_dwi.bvec", new_bvecs, fmt="%.6f")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Remove first volume from DWI and adjust bval/bvec."
    )
    parser.add_argument("dwi", help="Input diffusion MRI (4D .nii.gz)")
    parser.add_argument("bval", help="Input .bval file")
    parser.add_argument("bvec", help="Input .bvec file")
    parser.add_argument("out_prefix", help="Output prefix for new files")
    parser.add_argument("dir_orig", help="Original direction (AP or PA)")
    parser.add_argument("dir_new", help="New direction (AP or PA)")
    args = parser.parse_args()

    remove_first_volume(args.dwi, args.bval, args.bvec, args.out_prefix, args.dir_orig, args.dir_new)
