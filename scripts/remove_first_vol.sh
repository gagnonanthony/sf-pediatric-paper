#!/bin/bash

script_dir=$(dirname "$0")

for subj in sub-*; do

    ap_dwi="$subj/dwi/${subj}_dir-AP_dwi.nii.gz"
    pa_dwi="$subj/dwi/${subj}_dir-PA_dwi.nii.gz"

    if [[ -f "$ap_dwi" && -f "$pa_dwi" ]]; then
        # Look if the fmap folder exist.
        if [[ -d "$subj/fmap" && -n $(ls -A "$subj/fmap") ]]; then
            echo "Skipping $subj because fmap folder is not empty."
        else
            echo "Removing first volume AP DWI image in $subj"
            bash $script_dir/reorganize_subject.sh $subj AP PA
            bash $script_dir/reorganize_subject.sh $subj PA AP

            echo "Concatenating DWI images in $subj"
            scil_dwi_concatenate "$ap_dwi" $subj/dwi/${subj}_dir-AP_dwi.bval \
                $subj/dwi/${subj}_dir-AP_dwi.bvec \
                --in_dwis $subj/dwi/*nii.gz \
                --in_bvals $subj/dwi/*bval \
                --in_bvecs $subj/dwi/*bvec \
                -f

            echo "Removing PA file and AP fmap"
            rm $subj/dwi/*PA*
            rm $subj/fmap/*AP*
        fi
    fi
done
