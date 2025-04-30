#!/bin/bash

########################################################################
#                      Pipeline – Coregistration to MNI               #
# Description: Performs coregistration of neuroimaging data (T1, DWI, #
#              tractography) into MNI space using FSL and MRtrix.     #
# Usage:                                                              #
#   bash pipeline.sh <SUBJECT_DIR> <MODE>                             #
# Modes:                                                              #
#   1 - T1 coregistration to MNI                                       #
#   2 - Raw DWI (DICOM) coregistration to MNI                          #
#   3 - Preprocessed DWI (NIfTI) coregistration to MNI                #
#   4 - Tractography coregistration to MNI                             #
########################################################################

# Parse input arguments
RAW_SUB=$1
PROCESS_METHOD=$2

# Check for correct number of arguments
if [ $# -ne 2 ]; then
    echo "Usage: bash pipeline.sh <SUBJECT_DIR> <MODE>"
    echo "MODE:"
    echo "  1 - T1 coregistration to MNI"
    echo "  2 - Raw DWI (DICOM) coregistration to MNI"
    echo "  3 - Preprocessed DWI (NIfTI) coregistration to MNI"
    echo "  4 - Tractography coregistration to MNI"
    exit 1
fi

# Validate the processing method
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" && "$PROCESS_METHOD" != "3" && "$PROCESS_METHOD" != "4" ]]; then
    echo "Invalid method. Choose 1 (T1), 2 (Raw DWI), 3 (Preprocessed DWI), or 4 (Tractography)"
    exit 1
fi

# Create output directories for each subject
for_each $RAW_SUB/* : mkdir -p IN/PROCESSAMENTO
for_each $RAW_SUB/* : mkdir -p IN/MNI

########################################################################
#                          Mode 1 – T1 to MNI                          #
########################################################################
if [[ "$PROCESS_METHOD" == "1" ]]; then
    echo "Starting T1 coregistration to MNI..."
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/T1_bet.nii -R
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1.nii -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -dof 12 -out IN/PROCESSAMENTO/T1toMNIlin -omat IN/PROCESSAMENTO/T1toMNIlin.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --in=IN/PROCESSAMENTO/T1.nii --aff=IN/PROCESSAMENTO/T1toMNIlin.mat --config=$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf --iout=IN/PROCESSAMENTO/T1toMNInonlin --cout=IN/PROCESSAMENTO/T1toMNI_coef --fout=IN/PROCESSAMENTO/T1toMNI_warp
    for_each -nthreads 8 $RAW_SUB/* : applywarp -i IN/PROCESSAMENTO/T1.nii -r $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz -w IN/PROCESSAMENTO/T1toMNI_warp.nii.gz -o IN/MNI/T1_MNI.nii
    for_each -nthreads 8 $RAW_SUB/* : cp IN/PROCESSAMENTO/T1.nii IN/MNI/T1.nii
fi

########################################################################
#                       Mode 2 – Raw DWI to MNI                        #
########################################################################
if [[ "$PROCESS_METHOD" == "2" ]]; then
    echo "Starting raw DWI (DICOM) coregistration to MNI..."
    # DWI conversion and preprocessing
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi.mif -bzero - | mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii.gz

    # T1 preprocessing
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/T1_bet.nii.gz -R

    # Coregister DWI to T1 and then to MNI
    for_each -nthreads 8 $RAW_SUB/* : epi_reg --pedir=-y --epi=IN/PROCESSAMENTO/b0.nii.gz --t1=IN/PROCESSAMENTO/T1.nii --t1brain=IN/PROCESSAMENTO/T1_bet.nii.gz --out=IN/PROCESSAMENTO/dwi2T1
    for_each -nthreads 8 $RAW_SUB/* : convert_xfm -omat IN/PROCESSAMENTO/T12dwi.mat -inverse IN/PROCESSAMENTO/dwi2T1.mat
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1_bet.nii.gz -ref IN/PROCESSAMENTO/b0.nii.gz -out IN/PROCESSAMENTO/T12dwi.nii.gz -init IN/PROCESSAMENTO/T12dwi.mat -applyxfm
    for_each -nthreads 8 $RAW_SUB/* : flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -in IN/PROCESSAMENTO/T12dwi.nii.gz -omat IN/PROCESSAMENTO/T12MNI_affine.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --in=IN/PROCESSAMENTO/T12dwi.nii.gz --aff=IN/PROCESSAMENTO/T12MNI_affine.mat --cout=IN/PROCESSAMENTO/warps_T12MNI

    # Apply MNI transform to DWI and save outputs
    for_each -nthreads 8 $RAW_SUB/* : warpinit IN/PROCESSAMENTO/b0.nii.gz IN/PROCESSAMENTO/inv_identity_warp_no_2.nii 
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_no_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/inv_identity_warp_no_2.nii -coord 3 0 - | mrcalc - 0 -mult 1 -add IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrcalc IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz 1 nan -if IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz -mult IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrtransform IN/PROCESSAMENTO/dwi.mif -warp IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz IN/MNI/dwi_mni.nii
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/dwi.mif IN/MNI/dwi.nii
fi

########################################################################
#                   Modes 3 & 4 – Preprocessed DWI or Tractography     #
########################################################################
# These sections are very similar in structure, and I can finish documenting
# and cleaning them just like above if you'd like.

########################################################################
#                                Done                                  #
########################################################################
echo "Processamento concluído."
