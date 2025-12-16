#!/bin/sh

subject=$1

fslsplit $subject/fmap/*dir-AP_epi.nii.gz

mv vol0000.nii.gz $subject/fmap/${subject}_dir-AP_epi.nii.gz
mv vol0001.nii.gz $subject/fmap/${subject}_dir-PA_epi.nii.gz

cp $subject/fmap/${subject}_dir-AP_epi.json $subject/fmap/${subject}_dir-PA_epi.json

jq '.PhaseEncodingDirection = "j" + .PhaseEncodingDirection[2:]' $subject/fmap/${subject}_dir-PA_epi.json > $subject/fmap/tmp.json && mv $subject/fmap/tmp.json $subject/fmap/${subject}_dir-PA_epi.json