#!/bin/bash

script_dir=$(dirname "$0")
folder=$1
dir_orig=$2
dir_new=$3

if [ -z "$folder" ]; then
    echo "Usage: $0 <folder>"
    exit 1
fi

mkdir -p "$folder/fmap"

python $script_dir/extract_first_volume.py \
    $folder/dwi/${folder}_dir-${dir_orig}_dwi.nii.gz \
    $folder/dwi/${folder}_dir-${dir_orig}_dwi.bval \
    $folder/dwi/${folder}_dir-${dir_orig}_dwi.bvec \
    $folder \
    $dir_orig \
    $dir_new

scil_volume_flip $folder/fmap/${folder}_dir-${dir_new}_epi.nii.gz \
    $folder/fmap/${folder}_dir-${dir_new}_epi.nii.gz \
    x y -f

cp $folder/dwi/${folder}_dir-${dir_orig}_dwi.json $folder/fmap/${folder}_dir-${dir_new}_epi.json

if [ "$dir_new" = "PA" ]; then
    orient="j"
else
    orient="j-"
fi

# Swap the PhaseEncodingDirection in the JSON file to "j-"
jq '.PhaseEncodingDirection = "'"${orient}"'" + .PhaseEncodingDirection[2:]' $folder/fmap/${folder}_dir-${dir_new}_epi.json > $folder/fmap/tmp.json && mv $folder/fmap/tmp.json $folder/fmap/${folder}_dir-${dir_new}_epi.json
