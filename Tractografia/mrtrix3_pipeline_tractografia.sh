######################################################################
#                     Pipeline – DWI Completo                 
######################################################################

#Para rodar esse Pipeline é preciso ter instalado o software MRtrix3, FSL e ANTs.
#Modo de uso: 
#Opção de processamento sem aquisição B0 fase inversa
#$bash mrtrix3_pipeline.sh SUB 1
#Opção de processamento com aquisição B0 fase inversa
#$bash mrtrix3_pipeline.sh SUB 2

#SUB sendo as pastas com indivíduos, cada subpasta de cada individuo deve conter dois diretorios obrigatórios: DTI e 3DT1, com as respectivas imagens dicom (.dcm)
#e um opcional: B0 (b0 com fase inversa)
#Dessa forma a organizaçao de pastas seria:
#  SUB/
#      SUB_01/
#      SUB_02/
#       ...
#      SUB_N/
#            DTI/
#               00000.dcm
#               00001.dcm
#                ...
#            B0/
#               00000.dcm
#               00001.dcm
#                ...
#            3DT1/
#               00000.dcm
#               00001.dcm
#                ...

#!/bin/bash


RAW_SUB=$1
PROCESS_METHOD=$2
TRACTOGRAPHY_METHOD=$3

# Check if both arguments are provided
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


#1.	Converter imagens para extensão do MRtrix3
echo 'Conversão imagens de difusão dicom para mif (MRtrix3 format):'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
for_each $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
echo 'Conversão imagens anatômicas dicom para nifti:'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 

echo 'Remoção do ruído de fundo:'
for_each $RAW_SUB/* : dwidenoise IN/PROCESSAMENTO/dwi.mif IN/PROCESSAMENTO/dwi_denoised.mif -force
echo 'Remoção do ruído de gibbs:'
for_each $RAW_SUB/* : mrdegibbs IN/PROCESSAMENTO/dwi_denoised.mif IN/PROCESSAMENTO/dwi_degibbs.mif	-force	

# FSL Preprocessing (Correção de eddy currents, movimento e susceptibilidade magnética)
echo 'Pre-processamento FSL:'
if [[ "$PROCESS_METHOD" == "1" ]]; then
    # Se BO com fase inversa não existe, rodar o comando dwifslpreproc sem correçao de fase
    echo 'Pre-processamento FSL sem B0 com fase inversa:'
    for_each $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi_degibbs.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : dwifslpreproc -rpe_none -pe_dir AP IN/PROCESSAMENTO/dwi_degibbs.mif IN/PROCESSAMENTO/dwi_preproc.mif
fi

if [[ "$PROCESS_METHOD" == "2" ]]; then
    # Se B0 com fase inversa existe, rodar correção:
    echo 'Pre-processamento FSL com B0 com fase inversa:'
    for_each -nthreads 8 $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f b0_fase IN/B0/
    for_each -nthreads 8 $RAW_SUB/* : mrgrid IN/PROCESSAMENTO/dwi_degibbs.mif regrid -template IN/PROCESSAMENTO/b0_fase.nii IN/PROCESSAMENTO/dwi_degibbs_reg.mif 
    for_each -nthreads 8 $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi_degibbs_reg.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : mrcat IN/PROCESSAMENTO/b0.nii IN/PROCESSAMENTO/b0_fase.nii IN/PROCESSAMENTO/b0_pair.nii -axis 3
    for_each -nthreads 8 $RAW_SUB/* : dwifslpreproc IN/PROCESSAMENTO/dwi_degibbs_reg.mif IN/PROCESSAMENTO/dwi_preproc.mif -rpe_pair -se_epi IN/PROCESSAMENTO/b0_pair.nii -pe_dir AP -align_seepi
fi

echo 'Correção campo bias:'
for_each -nthreads 8 $RAW_SUB/* : dwibiascorrect ants IN/PROCESSAMENTO/dwi_preproc.mif IN/PROCESSAMENTO/dwi_bias.mif -force	

for_each $RAW_SUB/* : mkdir IN/PROCESSAMENTO/REG 
echo 'Remoção calota craniana:'
for_each $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1_bet.nii  -R
echo 'Cálculo matriz de alinhamento entre imagem de difusão e imagem anatômica:'	
for_each $RAW_SUB/* : flirt -dof 6 -cost normmi -in IN/PROCESSAMENTO/T1.nii -ref IN/PROCESSAMENTO/b0.nii -omat IN/PROCESSAMENTO/REG/T1_fsl.txt 	
echo 'Conversão da matriz para o formato do MRtrix3:'
for_each $RAW_SUB/* : transformconvert IN/PROCESSAMENTO/REG/T1_fsl.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/b0.nii flirt_import IN/PROCESSAMENTO/REG/T1toDWI.txt 
echo 'Corregistro da imagem anatômica para o espaço da imagem de difusão usando uma transformação linear:'
for_each $RAW_SUB/* : mrtransform -linear IN/PROCESSAMENTO/REG/T1toDWI.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1corregist.nii

echo 'Segmentação dos tecidos usando fsl'
for_each -nthreads 8 $RAW_SUB/* : 5ttgen fsl -nocrop -sgm_amyg_hipp IN/PROCESSAMENTO/REG/T1corregist.nii IN/PROCESSAMENTO/5ttseg.nii -force

echo 'Criação da máscara:'
for_each $RAW_SUB/* : dwi2mask IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/dwi_mask.mif

# Processing using FACT
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

# Processing using MTCSD
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

echo "Processamento concluído."
