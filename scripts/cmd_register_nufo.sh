#!/bin/sh

# Set up paths, arguments, etc.
folder_input=$1
template_t2w=$2
template_t1w=$3
processes=$4:8 # Use 8 processes by default

# Fetch the list of subjects from the input folder.
subjects=$(ls $folder_input/ | grep -E '^sub-') # Assuming subjects are named like sub-01, sub-02, etc.

# iterate over subjects
for sub in $subjects; do
    echo "Processing subject: $sub"
    sessions=$(ls $folder_input/$sub/ | grep -E '^ses-') # Assuming sessions are named like ses-01, ses-02, etc.

    for ses in $sessions; do
        # Check if the xfm folder exists.
        if [ -d $folder_input/$sub/$ses/xfm ]; then
            echo "XFM folder already exists for $sub/$ses, skipping registration."

            nufo_file=$folder_input/$sub/$ses/dwi/${sub}_${ses}_desc-nufo.nii.gz
            antsApplyTransforms -d 3 -i $nufo_file -r $template_t2w \
                -o $folder_input/$sub/$ses/dwi/${sub}_${ses}_space-UNCBCPCohort3_desc-nufo.nii.gz \
                -n NearestNeighbor -u int \
                -t $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-warp_xfm.nii.gz $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-affine_xfm.mat
            continue
        fi

        # Find the T2w image in DWI space.
        t2w_image=$folder_input/$sub/$ses/anat/${sub}_${ses}_space-DWI_desc-preproc_T2w.nii.gz
        t1w_image=$folder_input/$sub/$ses/anat/${sub}_${ses}_space-DWI_desc-preproc_T1w.nii.gz

        if [ -f $t1w_image ]; then
            image_to_register=$t1w_image
            template_file=$template_t1w
        else
            image_to_register=$t2w_image
            template_file=$template_t2w
        fi

        # Compute the registration.
        antsRegistrationSyN.sh -d 3 -f $template_file -m $image_to_register \
            -o output -t s -n $processes -e 1234

        mkdir -p $folder_input/$sub/$ses/xfm

        # Compute the inverse affine since we are here.
        antsApplyTransforms -d 3 -t [output0GenericAffine.mat,1] \
            -o Linear[output1GenericAffine.mat]

        # Move the registration files to the xfm folder.
        mv output0GenericAffine.mat $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-affine_xfm.mat
        mv output1Warp.nii.gz $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-warp_xfm.nii.gz
        mv output1InverseWarp.nii.gz $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-UNCBCPCohort3_to-dwi_mode-image_desc-warp_xfm.nii.gz
        mv output1GenericAffine.mat $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-UNCBCPCohort3_to-dwi_mode-image_desc-affine_xfm.mat

        # Warp the nufo file from dwi space to UNCBCPCohort3 space.
        nufo_file=$folder_input/$sub/$ses/dwi/${sub}_${ses}_desc-nufo.nii.gz
        antsApplyTransforms -d 3 -i $nufo_file -r $template_file \
            -o $folder_input/$sub/$ses/dwi/${sub}_${ses}_space-UNCBCPCohort3_desc-nufo.nii.gz \
            -n NearestNeighbor -u int \
            -t $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-warp_xfm.nii.gz $folder_input/$sub/$ses/xfm/${sub}_${ses}_from-dwi_to-UNCBCPCohort3_mode-image_desc-affine_xfm.mat

        rm output*.nii.gz

    done
done