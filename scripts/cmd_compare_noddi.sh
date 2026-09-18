#!/bin/sh

# Set up paths, arguments, etc.
folder_nopriors=$1
folder_priors=$2
output_file=$3

# Compute the mean of the rmse and nrmse for all subjects in both folders and write the results to the output file
# Fetch the list of subjects from the first folder
subjects=$(ls $folder_nopriors/ | grep -E '^sub-') # Assuming subjects are named like sub-01, sub-02, etc.

# Initialize the output file with headers
echo "sample,session,rmse_priors,rmse_std_priors,nrmse_priors,nrmse_std_priors,icvf_priors,ecvf_priors,isovf_priors,odi_priors,rmse_nopriors,rmse_std_nopriors,nrmse_nopriors,nrmse_std_nopriors,icvf_nopriors,ecvf_nopriors,isovf_nopriors,odi_nopriors" > $output_file

for sub in $subjects; do
    echo "Processing subject: $sub"
    # Fetch the sessions for this subject
    sessions=$(ls $folder_nopriors/$sub/ | grep -E '^ses-') # Assuming sessions are named like ses-01, ses-02, etc.
    
    for ses in $sessions; do
        # Compute the mean rmse and nrmse for this subject and session in both folders using mrstats
        rmse_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-rmse_dwimap.nii.gz
        nrmse_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-nrmse_dwimap.nii.gz
        icvf_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-icvf_dwimap.nii.gz
        ecvf_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-ecvf_dwimap.nii.gz
        isovf_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-isovf_dwimap.nii.gz
        odi_map_priors=$folder_priors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-odi_dwimap.nii.gz
        brain_mask_priors=$folder_priors/$sub/$ses/anat/${sub}_${ses}_space-DWI_label-WM*mask.nii.gz
        rmse_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $rmse_map_priors -mask - -output mean -ignorezero -quiet)
        rmse_priors_std=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $rmse_map_priors -mask - -output std -ignorezero -quiet)
        nrmse_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $nrmse_map_priors -mask - -output mean -ignorezero -quiet)
        nrmse_priors_std=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $nrmse_map_priors -mask - -output std -ignorezero -quiet)
        icvf_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $icvf_map_priors -mask - -output mean -ignorezero -quiet)
        ecvf_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $ecvf_map_priors -mask - -output mean -ignorezero -quiet)
        isovf_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $isovf_map_priors -mask - -output mean -ignorezero -quiet)
        odi_priors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $odi_map_priors -mask - -output mean -ignorezero -quiet)

        rmse_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-rmse_dwimap.nii.gz
        nrmse_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-nrmse_dwimap.nii.gz
        icvf_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-icvf_dwimap.nii.gz
        ecvf_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-ecvf_dwimap.nii.gz
        isovf_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-isovf_dwimap.nii.gz
        odi_map_nopriors=$folder_nopriors/$sub/$ses/dwi/${sub}_${ses}_model-noddi_param-odi_dwimap.nii.gz
        rmse_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $rmse_map_nopriors -mask - -output mean -ignorezero -quiet) # Using the same brain mask for both to ensure comparability
        rmse_nopriors_std=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $rmse_map_nopriors -mask - -output std -ignorezero -quiet)
        nrmse_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $nrmse_map_nopriors -mask - -output mean -ignorezero -quiet)
        nrmse_nopriors_std=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $nrmse_map_nopriors -mask - -output std -ignorezero -quiet)
        icvf_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $icvf_map_nopriors -mask - -output mean -ignorezero -quiet)
        ecvf_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $ecvf_map_nopriors -mask - -output mean -ignorezero -quiet)
        isovf_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $isovf_map_nopriors -mask - -output mean -ignorezero -quiet)
        odi_nopriors=$(mrthreshold -abs 0.5 $brain_mask_priors - | mrstats $odi_map_nopriors -mask - -output mean -ignorezero -quiet)

        # Write the results to the output file
        echo "$sub,$ses,$rmse_priors,$rmse_priors_std,$nrmse_priors,$nrmse_priors_std,$icvf_priors,$ecvf_priors,$isovf_priors,$odi_priors,$rmse_nopriors,$rmse_nopriors_std,$nrmse_nopriors,$nrmse_nopriors_std,$icvf_nopriors,$ecvf_nopriors,$isovf_nopriors,$odi_nopriors" >> $output_file
    done
done
