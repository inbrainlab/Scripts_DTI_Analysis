######################################################################
#                        MRtrix3 – Full DWI Pipeline                        #
######################################################################

# This pipeline requires MRtrix3, FSL, and ANTs installed and in your PATH.
#
# Usage:
# Without reversed-phase B0:
# $ bash mrtrix3_pipeline.sh SUB 1 1
# With reversed-phase B0:
# $ bash mrtrix3_pipeline.sh SUB 2 2
#
# <SUB> is the parent folder containing subject directories.
# Each subject directory must contain:
#   - DTI/   → DICOM files for DWI
#   - 3DT1/  → DICOM files for anatomical T1
#   - B0/    → (optional) DICOM files for reversed-phase B0

#!/bin/bash


RAW_SUB=$1
PROCESS_METHOD=$2
TRACTOGRAPHY_METHOD=$3

# Check input arguments
if [ $# -ne 3 ]; then
    echo "Uso: bash pipeline.sh <SUBJECTS> <1-PROCESSAMENTO-SEM-B0 | 2-PROCESSAMENTO-COM-B0-FASE-INVERSA > <1-FACT | 2-MTCSD | 3-Ambos>"
    exit 1
fi

# Verifique se o argumento do método é válido
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" ]]; then
    echo "Invalid choice. Use: (1) PROCESSAMENTO-SEM-B0, (2) PROCESSAMENTO-COM-B0-FASE-INVERSA"
    exit 1
fi

# Check if the method argument is valid
if [[ "$TRACTOGRAPHY_METHOD" != "1" && "$TRACTOGRAPHY_METHOD" != "2" && "$TRACTOGRAPHY_METHOD" != "3" ]]; then
    echo "Escolha inválida. Use: (1) FACT, (2) MTCSD, (3) Ambos"
    exit 1
fi


# Step 1: Convert DICOM to MRtrix and NIfTI formats
echo 'Conversão imagens de difusão dicom para mif (MRtrix3 format):'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
for_each $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
echo 'Conversão imagens anatômicas dicom para nifti:'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 

# Step 2: Denoising and artifact correction
echo 'Remoção do ruído de fundo:'
for_each $RAW_SUB/* : dwidenoise IN/PROCESSAMENTO/dwi.mif IN/PROCESSAMENTO/dwi_denoised.mif -force
echo 'Remoção do ruído de gibbs:'
for_each $RAW_SUB/* : mrdegibbs IN/PROCESSAMENTO/dwi_denoised.mif IN/PROCESSAMENTO/dwi_degibbs.mif	-force	

# Step 3: FSL Preprocessing (Eddy, motion, susceptibility correction)
echo 'Pre-processamento FSL:'
if [[ "$PROCESS_METHOD" == "1" ]]; then
    # Se BO com fase inversa não existe, rodar o comando dwifslpreproc sem correçao de fase
    echo 'Pre-processamento FSL sem B0 com fase inversa:'
    for_each $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi_degibbs.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : dwifslpreproc -rpe_none -pe_dir AP IN/PROCESSAMENTO/dwi_degibbs.mif IN/PROCESSAMENTO/dwi_preproc.mif
else
    # Se B0 com fase inversa existe, rodar correção:
    echo 'Pre-processamento FSL com B0 com fase inversa:'
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f b0_fase IN/B0/
    for_each -nthreads 8 $RAW_SUB/* : mrgrid IN/PROCESSAMENTO/dwi_degibbs.mif regrid -template IN/PROCESSAMENTO/b0_fase.nii IN/PROCESSAMENTO/dwi_degibbs_reg.mif 
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi_degibbs_reg.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : mrcat IN/PROCESSAMENTO/b0.nii IN/PROCESSAMENTO/b0_fase.nii IN/PROCESSAMENTO/b0_pair.nii -axis 3
    for_each -nthreads 8 $RAW_SUB/* : dwifslpreproc IN/PROCESSAMENTO/dwi_degibbs_reg.mif IN/PROCESSAMENTO/dwi_preproc.mif -rpe_pair -se_epi IN/PROCESSAMENTO/b0_pair.nii -pe_dir AP -align_seepi
fi

# Step 4: Bias field correction
echo 'Correção campo bias:'
for_each -nthreads 8 $RAW_SUB/* : dwibiascorrect ants IN/PROCESSAMENTO/dwi_preproc.mif IN/PROCESSAMENTO/dwi_bias.mif -force	

# Step 5: T1 processing and registration
for_each $RAW_SUB/* : mkdir IN/PROCESSAMENTO/REG 
echo 'Remoção calota craniana:'
for_each $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1_bet.nii  -R
echo 'Cálculo matriz de alinhamento entre imagem de difusão e imagem anatômica:'	
for_each $RAW_SUB/* : flirt -dof 6 -cost normmi -in IN/PROCESSAMENTO/T1.nii -ref IN/PROCESSAMENTO/b0.nii -omat IN/PROCESSAMENTO/REG/T1_fsl.txt 	
echo 'Conversão da matriz para o formato do MRtrix3:'
for_each $RAW_SUB/* : transformconvert IN/PROCESSAMENTO/REG/T1_fsl.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/b0.nii flirt_import IN/PROCESSAMENTO/REG/T1toDWI.txt 
echo 'Corregistro da imagem anatômica para o espaço da imagem de difusão usando uma transformação linear:'
for_each $RAW_SUB/* : mrtransform -linear IN/PROCESSAMENTO/REG/T1toDWI.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1corregist.nii

# Step 6: Tissue segmentation
echo 'Segmentação dos tecidos usando fsl'
for_each -nthreads 8 $RAW_SUB/* : 5ttgen fsl -nocrop -sgm_amyg_hipp IN/PROCESSAMENTO/REG/T1corregist.nii IN/PROCESSAMENTO/5ttseg.nii -force

# Step 7: Create brain mask
echo 'Criação da máscara:'
for_each $RAW_SUB/* : dwi2mask IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/dwi_mask.mif

# Step 8: FACT Tractography
if [[ "$TRACTOGRAPHY_METHOD" == "1" || "$TRACTOGRAPHY_METHOD" == "3" ]]; then
    echo 'Criação do tensor:'
    for_each -nthreads 8 $RAW_SUB/* : dwi2tensor -mask IN/PROCESSAMENTO/dwi_mask.mif IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/dwi_tensor.mif -force
    
    echo 'Obtenção das métricas:'
    for_each -nthreads 8 $RAW_SUB/* : tensor2metric -vec IN/PROCESSAMENTO/dwi_vec.mif IN/PROCESSAMENTO/dwi_tensor.mif -force #vector file
    
    echo 'Rastreamento das fibras com FACT:'
    for_each -nthreads 8 $RAW_SUB/* : tckgen -algorithm FACT IN/PROCESSAMENTO/dwi_vec.mif IN/PROCESSAMENTO/FACT.tck \
    -select 1M -seed_image IN/PROCESSAMENTO/dwi_mask.mif -act IN/PROCESSAMENTO/5ttseg.nii \
    -crop_at_gmwmi -angle 45 -cutoff 0.06 -force	#tractography generation
fi

# Step 9: MTCSD Tractography
if [[ "$TRACTOGRAPHY_METHOD" == "2" || "$TRACTOGRAPHY_METHOD" == "3" ]]; then
    echo 'dwi2response:'
    for_each -nthreads 8 $RAW_SUB/* : dwi2response dhollander IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/wm_response_01.txt \
    IN/PROCESSAMENTO/gm_response.txt IN/PROCESSAMENTO/csf_response.txt -force
    
    echo 'dwi2fod:'
    for_each -nthreads 8 $RAW_SUB/* : dwi2fod msmt_csd -mask IN/PROCESSAMENTO/dwi_mask.mif IN/PROCESSAMENTO/dwi_bias.mif \
    IN/PROCESSAMENTO/wm_response_01.txt IN/PROCESSAMENTO/wm_fod.mif IN/PROCESSAMENTO/gm_response.txt \
    IN/PROCESSAMENTO/gm_fod.mif IN/PROCESSAMENTO/csf_response.txt IN/PROCESSAMENTO/csf_fod.mif -force #multi-tissue CSD
    
    echo 'Rastreamento das fibras com iFOD2:'
    for_each -nthreads 8 $RAW_SUB/* : tckgen -algorithm iFOD2 IN/PROCESSAMENTO/wm_fod.mif IN/PROCESSAMENTO/MTCSD.tck \
    -select 1M -seed_dynamic IN/PROCESSAMENTO/wm_fod.mif -act IN/PROCESSAMENTO/5ttseg.nii \
    -backtrack -crop_at_gmwmi -cutoff 0.06 -force
fi

echo "✔️  Processamento concluído."
