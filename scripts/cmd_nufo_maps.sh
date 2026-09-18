#!/bin/sh

# Set up paths, arguments, etc.
folder_nopriors=$1
folder_priors=$2
reference=$3
output_folder=$4

# List of subjects in the folder
subjects=$(ls $folder_nopriors/ | grep -E '^sub-') # Assuming subjects are named like sub-01, sub-02, etc.
mkdir -p $output_folder/nufo_maps/
mkdir -p $output_folder/nufo_maps_registered/

for sub in $subjects; do
    echo "Processing subject: $sub"
    # List of sessions for this subject
    sessions=$(ls $folder_nopriors/$sub/ | grep -E '^ses-') # Assuming sessions are named like ses-01, ses-02, etc.
    for ses in $sessions; do
        noprior_nufo=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_desc-nufo.nii.gz
        priors_nufo=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_desc-nufo.nii.gz

        # Use mrtrix to compute the difference between the two nufo maps
        mrcalc $priors_nufo $noprior_nufo -subtract $output_folder/nufo_maps/${sub}_${ses}_desc-nufo_diff.nii.gz -quiet -datatype int16

        # Register the difference map to the reference space.
        antsApplyTransforms -d 3 -i $output_folder/nufo_maps/${sub}_${ses}_desc-nufo_diff.nii.gz -r $reference \
            -o $output_folder/nufo_maps_registered/${sub}_${ses}_space-UNCBCPCohort3_desc-nufo_diff.nii.gz \
            -n NearestNeighbor -u int \
            -t $folder_priors/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-warp_xfm.nii.gz $folder_priors/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-affine_xfm.mat
    done
done

# compute the average of all the difference maps
mrmath $output_folder/nufo_maps/*.nii.gz mean $output_folder/average_diff.nii.gz -quiet -datatype float32
