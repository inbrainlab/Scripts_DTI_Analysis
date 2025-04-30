######################################################################
#                     Pipeline – Corregistro MNI               
######################################################################


RAW_SUB=$1

if [ $# -ne 2 ]; then
    echo "Uso: bash pipeline.sh <SUBJECTS> <1-Corregistro T1 para MNI | 2-Corregistro DWI DICOM para MNI | 3-Corregistro DWI NIFTI para MNI | 4-Corregistro Tractografia para MNI >"
    exit 1
fi

RAW_SUB=$1
PROCESS_METHOD=$2

# Check if the method argument is valid
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" && "$PROCESS_METHOD" != "3" && "$PROCESS_METHOD" != "4" ]]; then
    echo "Escolha inválida. Use: (1) Corregistro T1, (2) Corregistro DWI DICOM/BRUTO, (3) Corregistro DWI preprocessado (NIFTI), (4) Corregistro Tractografia"
    exit 1
fi

#Criar pasta para salvar os outputs do pre-processamento
for_each $RAW_SUB/* : mkdir IN/PROCESSAMENTO
for_each $RAW_SUB/* : mkdir IN/MNI

if [[ "$PROCESS_METHOD" == "1" ]]; then
    echo 'Corregistro imagem anatômica (T1) para espaço padrão (MNI):'
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/T1_bet.nii  -R
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1.nii -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -dof 12 -out IN/PROCESSAMENTO/T1toMNIlin -omat IN/PROCESSAMENTO/T1toMNIlin.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --in=IN/PROCESSAMENTO/T1.nii --aff=IN/PROCESSAMENTO/T1toMNIlin.mat --config=$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf --iout=IN/PROCESSAMENTO/T1toMNInonlin --cout=IN/PROCESSAMENTO/T1toMNI_coef --fout=IN/PROCESSAMENTO/T1toMNI_warp
    for_each -nthreads 8 $RAW_SUB/* : applywarp -i IN/PROCESSAMENTO/T1.nii -r $FSLDIR/data/standard/MNI152_T1_1mm.nii.gz -w IN/PROCESSAMENTO/T1toMNI_warp.nii.gz -o IN/MNI/T1_MNI.nii
    for_each -nthreads 8 $RAW_SUB/* : cp IN/PROCESSAMENTO/T1.nii IN/MNI/T1.nii
fi

if [[ "$PROCESS_METHOD" == "2" ]]; then
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii.gz

    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/T1_bet.nii.gz  -R

    for_each -nthreads 8 $RAW_SUB/* : epi_reg --pedir=-y --epi=IN/PROCESSAMENTO/b0.nii.gz --t1=IN/PROCESSAMENTO/T1.nii --t1brain=IN/PROCESSAMENTO/T1_bet.nii.gz --out=IN/PROCESSAMENTO/dwi2T1
    for_each -nthreads 8 $RAW_SUB/* : convert_xfm -omat IN/PROCESSAMENTO/T12dwi.mat -inverse IN/PROCESSAMENTO/dwi2T1.mat
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1_bet.nii.gz -ref IN/PROCESSAMENTO/b0.nii.gz -out IN/PROCESSAMENTO/T12dwi.nii.gz -init IN/PROCESSAMENTO/T12dwi.mat -applyxfm
    for_each -nthreads 8 $RAW_SUB/* : flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -in IN/PROCESSAMENTO/T12dwi.nii.gz -omat IN/PROCESSAMENTO/T12MNI_affine.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --in=IN/PROCESSAMENTO/T12dwi.nii.gz --aff=IN/PROCESSAMENTO/T12MNI_affine.mat --cout=IN/PROCESSAMENTO/warps_T12MNI

    echo 'Corregistro entre DWI e MNI'
    for_each -nthreads 8 $RAW_SUB/* : warpinit  IN/PROCESSAMENTO/b0.nii.gz  IN/PROCESSAMENTO/inv_identity_warp_no_2.nii 
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_no_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/inv_identity_warp_no_2.nii  -coord 3 0 - \| mrcalc - 0 -mult 1 -add IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii

    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz 
    for_each -nthreads 8 $RAW_SUB/* : mrcalc IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz 1 nan -if IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz -mult IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrtransform IN/PROCESSAMENTO/dwi.mif -warp IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz IN/MNI/dwi_mni.nii   # Check the transformation
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/dwi.mif IN/MNI/dwi.nii
fi

if [[ "$PROCESS_METHOD" == "3" ]]; then
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi.nii -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/T1_bet.nii  -R

    for_each -nthreads 8 $RAW_SUB/* : epi_reg --pedir=-y --epi=IN/PROCESSAMENTO/b0.nii --t1=IN/PROCESSAMENTO/T1.nii --t1brain=IN/PROCESSAMENTO/T1_bet.nii --out=IN/PROCESSAMENTO/dwi2T1
    for_each -nthreads 8 $RAW_SUB/* : convert_xfm -omat IN/PROCESSAMENTO/T12dwi.mat -inverse IN/PROCESSAMENTO/dwi2T1.mat
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1_bet.nii -ref IN/PROCESSAMENTO/b0.nii -out IN/PROCESSAMENTO/T12dwi.nii.gz -init IN/PROCESSAMENTO/T12dwi.mat -applyxfm
    for_each -nthreads 8 $RAW_SUB/* : flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -in IN/PROCESSAMENTO/T12dwi.nii.gz -omat IN/PROCESSAMENTO/T12MNI_affine.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --config=$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf --in=IN/PROCESSAMENTO/T12dwi.nii.gz --aff=IN/PROCESSAMENTO/T12MNI_affine.mat --cout=IN/PROCESSAMENTO/warps_T12MNI

    echo 'Corregistro entre DWI e MNI'
    for_each -nthreads 8 $RAW_SUB/* : warpinit  IN/PROCESSAMENTO/b0.nii  IN/PROCESSAMENTO/inv_identity_warp_no_2.nii 
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_no_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/inv_identity_warp_no_2.nii  -coord 3 0 - \| mrcalc - 0 -mult 1 -add IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii

    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_mask_2.nii --warp=IN/PROCESSAMENTO/warps_T12MNI.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz 
    for_each -nthreads 8 $RAW_SUB/* : mrcalc IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_mask.nii.gz 1 nan -if IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI.nii.gz -mult IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrtransform IN/PROCESSAMENTO/dwi.nii -warp IN/PROCESSAMENTO/mrtrix_warp_dwi2MNI_valid.nii.gz IN/MNI/dwi_mni.nii   # Check the transformation
fi

if [[ "$PROCESS_METHOD" == "4" ]]; then
    
    echo 'Conversão imagens de difusão dicom para mif (MRtrix3 format):'
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii.gz
    echo 'Conversão imagens anatômicas dicom para nifti:'
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 
    for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii.gz IN/PROCESSAMENTO/T1_bet.nii.gz  -R

    echo 'Corregistro entre Tractografia e MNI'
    for_each -nthreads 8 $RAW_SUB/* : epi_reg --pedir=-y --epi=IN/PROCESSAMENTO/b0.nii.gz --t1=IN/PROCESSAMENTO/T1.nii.gz --t1brain=IN/PROCESSAMENTO/T1_bet.nii.gz --out=IN/PROCESSAMENTO/dwi2T1
    for_each -nthreads 8 $RAW_SUB/* : convert_xfm -omat IN/PROCESSAMENTO/T12dwi.mat -inverse IN/PROCESSAMENTO/dwi2T1.mat
    for_each -nthreads 8 $RAW_SUB/* : flirt -in IN/PROCESSAMENTO/T1_bet.nii.gz -ref IN/PROCESSAMENTO/b0.nii.gz -out IN/PROCESSAMENTO/T12dwi.nii.gz -init IN/PROCESSAMENTO/T12dwi.mat -applyxfm
    for_each -nthreads 8 $RAW_SUB/* : flirt -ref $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -in IN/PROCESSAMENTO/T12dwi.nii.gz -omat IN/PROCESSAMENTO/T12MNI_affine.mat
    for_each -nthreads 8 $RAW_SUB/* : fnirt --ref=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz --in=IN/PROCESSAMENTO/T12dwi.nii.gz --aff=IN/PROCESSAMENTO/T12MNI_affine.mat --cout=IN/PROCESSAMENTO/warps_T12MNI
    for_each -nthreads 8 $RAW_SUB/* : invwarp --ref=IN/PROCESSAMENTO/T12dwi.nii.gz --warp=IN/PROCESSAMENTO/warps_T12MNI --out=IN/PROCESSAMENTO/warps_MNI2T1
    for_each -nthreads 8 $RAW_SUB/* : warpinit $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz IN/PROCESSAMENTO/inv_identity_warp_no.nii 
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=IN/PROCESSAMENTO/b0.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_no.nii --warp=IN/PROCESSAMENTO/warps_MNI2T1.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/inv_identity_warp_no.nii  -coord 3 0 - \| mrcalc - 0 -mult 1 -add IN/PROCESSAMENTO/inv_identity_warp_mask.nii
    for_each -nthreads 8 $RAW_SUB/* : applywarp --ref=IN/PROCESSAMENTO/b0.nii.gz --in=IN/PROCESSAMENTO/inv_identity_warp_mask.nii --warp=IN/PROCESSAMENTO/warps_MNI2T1.nii.gz --out=IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi_mask.nii.gz 
    for_each -nthreads 8 $RAW_SUB/* : mrcalc IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi_mask.nii.gz 1 nan -if IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi.nii.gz -mult IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi_valid.nii.gz
    for_each -nthreads 8 $RAW_SUB/* : mrtransform $FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz -warp IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi_valid.nii.gz IN/PROCESSAMENTO/MNI2dwi.nii.gz   
    for_each -nthreads 8 $RAW_SUB/* : tcktransform IN/TRACTO/*.tck IN/PROCESSAMENTO/mrtrix_warp_MNI2dwi_valid.nii.gz IN/MNI/tractography_mni.tck 
fi

#for_each $RAW_SUB/* : rm -r IN/PROCESSAMENTO
echo "Processamento concluído."