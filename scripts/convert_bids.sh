#!/bin/sh

for archive in *.zip; do
    # Extract the subject name matching the pattern "PXXXX"
    subject=$(echo "$archive" | grep -oE 'P[0-9]{4}')

    # Extract the archive
    unzip -qq "$archive"

    # Clean for dotfiles.
    dot_clean -m $subject

    # Enter the subject directory
    cd $subject/${subject}_*/data/ping_dicoms/files/

    # Convert the DICOM files to NIfTI format
    dcm2bids -d ${subject}* -p $subject \
        -c ~/code/nf-pediatric-paper/dcm2bids_config_PING.json \
        -o /Volumes/T7/PING/bids/
    
    # Remove the subject directory
    cd ../../../../..
    rm -rf $subject

done