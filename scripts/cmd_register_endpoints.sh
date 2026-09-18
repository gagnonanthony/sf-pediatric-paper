#!/bin/sh

input_folder=$1
template=$2
processes=$3
output_folder=$4
apptainer_image=$5

# Fetch the list of subjects from the input folder.
subjects=$(ls $input_folder/ | grep -E '^sub-') # Assuming subjects are named like sub-01, sub-02, etc.

mkdir -p $output_folder/endpoints $output_folder/endpoints_registered

# iterate over subjects
for sub in $subjects; do
    echo "Processing subject: $sub"
    sessions=$(ls $input_folder/$sub/ | grep -E '^ses-') # Assuming sessions are named like ses-01, ses-02, etc.

    for ses in $sessions; do
        pyt_l=$input_folder/$sub/$ses/dwi/bundles/${sub}_${ses}_desc-PYT_L.trk
        pyt_r=$input_folder/$sub/$ses/dwi/bundles/${sub}_${ses}_desc-PYT_R.trk

        apptainer run $apptainer_image scil_bundle_compute_endpoints_map \
            $pyt_l $output_folder/endpoints/${sub}_${ses}_desc-PYT_L_head.nii.gz \
            $output_folder/endpoints/${sub}_${ses}_desc-PYT_L_tail.nii.gz
        apptainer run $apptainer_image scil_bundle_compute_endpoints_map \
            $pyt_r $output_folder/endpoints/${sub}_${ses}_desc-PYT_R_head.nii.gz \
            $output_folder/endpoints/${sub}_${ses}_desc-PYT_R_tail.nii.gz
        apptainer run $apptainer_image scil_volume_math addition \
            $output_folder/endpoints/${sub}_${ses}_desc-PYT_R_tail.nii.gz $output_folder/endpoints/${sub}_${ses}_desc-PYT_L_tail.nii.gz \
            $output_folder/endpoints/${sub}_${ses}_desc-PYT_tails.nii.gz
        antsApplyTransforms -d 3 -i $output_folder/endpoints/${sub}_${ses}_desc-PYT_tails.nii.gz \
            -r $template \
            -o $output_folder/endpoints_registered/${sub}_${ses}_space-UNCBCPCohort3_desc-PYT_tails.nii.gz \
            -n Linear \
            -t $input_folder/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-warp_xfm.nii.gz $input_folder/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-affine_xfm.mat
    done
done