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

# Verificar se ambos os argumentos são fornecidos
if [ $# -ne 2 ]; then
    echo "Uso: bash pipeline.sh <SUBJECTS> <1-PROCESSAMENTO-SEM-B0 | 2-PROCESSAMENTO-COM-B0-FASE-INVERSA >"
    exit 1
fi

RAW_SUB=$1
PROCESS_METHOD=$2

# Verifique se o argumento do método é válido
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" ]]; then
    echo "Invalid choice. Use: (1) PROCESSAMENTO-SEM-B0, (2) PROCESSAMENTO-COM-B0-FASE-INVERSA"
    exit 1
fi


# Pré-processamento
# Criar pasta para salvar os outputs do pre-processamento
for_each $RAW_SUB/* : mkdir IN/PROCESSAMENTO
#1.	Converter imagens para extensão do MRtrix3
echo 'Conversão imagens de difusão dicom para mif (MRtrix3 format):'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f DTI IN/DTI/
for_each $RAW_SUB/* : mrconvert IN/PROCESSAMENTO/DTI.nii -fslgrad IN/PROCESSAMENTO/DTI.bvec IN/PROCESSAMENTO/DTI.bval IN/PROCESSAMENTO/dwi.mif
echo 'Conversão imagens anatômicas dicom para nifti:'
for_each $RAW_SUB/* : dcm2niix -o IN/PROCESSAMENTO/ -f T1 IN/3DT1/ 

#Correção de ruído, gibbs e bias field
#Correção de ruído de fundo
echo 'Remoção do ruído de fundo:'
for_each -nthreads 8 $RAW_SUB/* : dwidenoise IN/PROCESSAMENTO/dwi.mif IN/PROCESSAMENTO/dwi_denoised.mif
#Correção de ruído de gibbs
echo 'Remoção do ruído de gibbs:'
for_each -nthreads 8 $RAW_SUB/* : mrdegibbs IN/PROCESSAMENTO/dwi_denoised.mif IN/PROCESSAMENTO/dwi_degibbs.mif		

# FSL Preprocessing (Correção de eddy currents, movimento e susceptibilidade magnética)
echo 'Pre-processamento FSL:'
if [[ "$PROCESS_METHOD" == "1" ]]; then
    # Se BO com fase inversa não existe, rodar o comando dwifslpreproc sem correçao de fase
    echo 'Pre-processamento FSL sem B0 com fase inversa:'
    for_each $RAW_SUB/* : mrgrid IN/PROCESSAMENTO/dwi_degibbs.mif regrid -size 128,128,72 IN/PROCESSAMENTO/dwi_degibbs_reg.mif
    for_each $RAW_SUB/* : dwiextract IN/PROCESSAMENTO/dwi_degibbs_reg.mif -bzero - \| mrmath -axis 3 - mean IN/PROCESSAMENTO/b0.nii
    for_each -nthreads 8 $RAW_SUB/* : dwifslpreproc -rpe_none -pe_dir AP IN/PROCESSAMENTO/dwi_degibbs_reg.mif IN/PROCESSAMENTO/dwi_preproc.mif
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

#Correção de ruído de campo (bias field)
echo 'Correção campo bias:'
for_each -nthreads 8 $RAW_SUB/* : dwibiascorrect ants IN/PROCESSAMENTO/dwi_preproc.mif IN/PROCESSAMENTO/dwi_bias.mif

#Corregistro entre imagem de difusão (DWI) e anatômica (3DT1)
#Criar pasta para salvar os outputs do corregistro
for_each $RAW_SUB/* : mkdir IN/PROCESSAMENTO/REG
#Retirar calota craniana e o que não for encéfalo
echo 'Remoção calota craniana:'
for_each -nthreads 8 $RAW_SUB/* : bet IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1_bet.nii  -R
#Cálculo matriz de alinhamento entre imagem de difusão e imagem anatômica
echo 'Cálculo matriz de alinhamento entre imagem de difusão e imagem anatômica:'	
for_each -nthreads 8 $RAW_SUB/* : flirt -dof 6 -cost normmi -in IN/PROCESSAMENTO/T1.nii -ref IN/PROCESSAMENTO/b0.nii -omat IN/PROCESSAMENTO/REG/T1_fsl.txt 	
#Conversão da matriz para o formato do MRtrix3
echo 'Conversão da matriz para o formato do MRtrix3:'
for_each $RAW_SUB/* : transformconvert IN/PROCESSAMENTO/REG/T1_fsl.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/b0.nii flirt_import IN/PROCESSAMENTO/REG/T1toDWI.txt 
#Corregistro da imagem anatômica para o espaço da imagem de difusão usando uma transformação linear
echo 'Corregistro da imagem anatômica para o espaço da imagem de difusão usando uma transformação linear:'
for_each $RAW_SUB/* : mrtransform -linear IN/PROCESSAMENTO/REG/T1toDWI.txt IN/PROCESSAMENTO/T1.nii IN/PROCESSAMENTO/REG/T1corregist.nii
#Segmentação dos tecidos (Substancia cinzenta cortical, Substância cinzenta subcortical, Substância branca, Líquor, Tecido patológico)
echo 'Segmentação dos tecidos usando fsl'
for_each -nthreads 8 $RAW_SUB/* : 5ttgen fsl -nocrop -sgm_amyg_hipp IN/PROCESSAMENTO/REG/T1corregist.nii IN/PROCESSAMENTO/5ttseg.nii -force
#Extrair apenas a máscara da substância branca
echo 'Extrair apenas a máscara da substância branca:'
for_each $RAW_SUB/* : mrconvert -coord 3 2 -axes 0,1,2 IN/PROCESSAMENTO/5ttseg.nii IN/PROCESSAMENTO/wm.nii 

echo 'Deixar as imagens com as mesmas dimensões:'
for_each $RAW_SUB/* : mrregister IN/PROCESSAMENTO/wm.nii IN/PROCESSAMENTO/dwi_bias.mif -type affine -transformed IN/PROCESSAMENTO/wm_regrid.nii 

#fslinfo input.nii, então se 'dim1' for 128, você substituiria 'halfx' por 64 -> metade do número de voxels ao longo da dimensão X
echo 'Separar mascaras em hemisfério direito e esquerdo:'
for_each $RAW_SUB/* : fslmaths IN/PROCESSAMENTO/wm_reg.nii -roi 0 64 0 -1 0 -1 0 -1 IN/PROCESSAMENTO/left_wm_reg.nii.gz  
for_each $RAW_SUB/* : fslmaths IN/PROCESSAMENTO/wm_reg.nii -roi 64 128 0 -1 0 -1 0 -1 IN/PROCESSAMENTO/right_wm_reg.nii.gz  

#Mapa de FA, MD, AD e RD
#Criar pasta para salvar os mapas
for_each $RAW_SUB/* : mkdir IN/MAPAS
#Extrair máscara do cérebro inteiro
echo 'Extrair máscara do cérebro inteiro'
for_each $RAW_SUB/* : dwi2mask IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/dwi_mask.mif 
#Cálculo do tensor de difusão
echo 'Cálculo do tensor de difusão:'
for_each $RAW_SUB/* : dwi2tensor -mask IN/PROCESSAMENTO/dwi_mask.mif IN/PROCESSAMENTO/dwi_bias.mif IN/PROCESSAMENTO/dwi_tensor.mif  
#Geração dos mapas de FA, MD, AD, RD
echo 'Geração dos mapas de FA, FA colorido, MD, AD, RD:'
for_each $RAW_SUB/* : tensor2metric -adc IN/MAPAS/MAPA_MD.nii -fa IN/MAPAS/MAPA_FA.nii -ad IN/MAPAS/MAPA_AD.nii -rd IN/MAPAS/MAPA_RD.nii -mask IN/PROCESSAMENTO/dwi_mask.mif IN/PROCESSAMENTO/dwi_tensor.mif 

#Obter valores médios de FA da substância branca
#Criar pasta para salvar os resultados
for_each $RAW_SUB/* : mkdir IN/RESULTADOS
mkdir RESULTADOS
#obter as métricas
echo 'Obter valores médios de FA para toda a substância branca:'
#Obter a métrica de FA de cada indivíduo e salvar dentro da pasta do indivíduo
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_FA.nii -mask IN/PROCESSAMENTO/wm_reg.nii -output mean '>' IN/RESULTADOS/RESULTADO_FA.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_FA.nii -mask IN/PROCESSAMENTO/left_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_FA_ESQUERDO.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_FA.nii -mask IN/PROCESSAMENTO/right_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_FA_DIREITO.txt
#Obter a métrica de FA de cada indivíduo e salvar em um único arquivo todos os valores de FA obtidos para cada indivíduo, no caso
for dir in $RAW_SUB/*; do
    # Extract the directory name (individual identifier)
    individual_name=$(basename "$dir")

    # Read the individual FA result from the previously generated file
    if [ -f "$dir/RESULTADOS/RESULTADO_FA.txt" ]; then
        fa_value=$(cat "$dir/RESULTADOS/RESULTADO_FA.txt")
    else
        fa_value="No FA result found"
    fi

    # Read the individual FA left result
    if [ -f "$dir/RESULTADOS/RESULTADO_FA_ESQUERDO.txt" ]; then
        fa_left_value=$(cat "$dir/RESULTADOS/RESULTADO_FA_ESQUERDO.txt")
    else
        fa_left_value="No FA left result found"
    fi

    # Read the individual FA right result
    if [ -f "$dir/RESULTADOS/RESULTADO_FA_DIREITO.txt" ]; then
        fa_right_value=$(cat "$dir/RESULTADOS/RESULTADO_FA_DIREITO.txt")
    else
        fa_right_value="No FA right result found"
    fi

    # Append the individual's name and their FA values to the main result file
    echo "$individual_name: FA_total: $fa_value, FA_esquerdo: $fa_left_value, FA_direito: $fa_right_value" >> RESULTADOS/RESULTADOS_FA.txt
done


echo 'Obter valores médios de MD para toda a substância branca:'
#Obter a métrica de MD de cada indivíduo e salvar dentro da pasta do indivíduo
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_MD.nii -mask IN/PROCESSAMENTO/wm_reg.nii -output mean '>' IN/RESULTADOS/RESULTADO_MD.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_MD.nii -mask IN/PROCESSAMENTO/left_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_MD_ESQUERDO.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_MD.nii -mask IN/PROCESSAMENTO/right_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_MD_DIREITO.txt
#Obter a métrica de MD de cada indivíduo e salvar em um único arquivo todos os valores de MD obtidos para cada indivíduo, no caso
for dir in $RAW_SUB/*; do
    # Extract the directory name (individual identifier)
    individual_name=$(basename "$dir")

    # Read the individual FA result from the previously generated file
    if [ -f "$dir/RESULTADOS/RESULTADO_MD.txt" ]; then
        md_value=$(cat "$dir/RESULTADOS/RESULTADO_MD.txt")
    else
        md_value="No MD result found"
    fi

    # Read the individual FA left result
    if [ -f "$dir/RESULTADOS/RESULTADO_MD_ESQUERDO.txt" ]; then
        md_left_value=$(cat "$dir/RESULTADOS/RESULTADO_MD_ESQUERDO.txt")
    else
        md_left_value="No MD left result found"
    fi

    # Read the individual FA right result
    if [ -f "$dir/RESULTADOS/RESULTADO_MD_DIREITO.txt" ]; then
        md_right_value=$(cat "$dir/RESULTADOS/RESULTADO_MD_DIREITO.txt")
    else
        md_right_value="No MD right result found"
    fi

    # Append the individual's name and their FA values to the main result file
    echo "$individual_name: MD_total: $md_value, MD_esquerdo: $md_left_value, MD_direito: $md_right_value" >> RESULTADOS/RESULTADOS_MD.txt
done




echo 'Obter valores médios de AD para toda a substância branca:'
#Obter a métrica de AD de cada indivíduo e salvar dentro da pasta do indivíduo
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_AD.nii -mask IN/PROCESSAMENTO/wm_reg.nii -output mean '>' IN/RESULTADOS/RESULTADO_AD.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_AD.nii -mask IN/PROCESSAMENTO/left_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_AD_ESQUERDO.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_AD.nii -mask IN/PROCESSAMENTO/right_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_AD_DIREITO.txt
#Obter a métrica de AD de cada indivíduo e salvar em um único arquivo todos os valores de AD obtidos para cada indivíduo, no caso
for dir in $RAW_SUB/*; do
    # Extract the directory name (individual identifier)
    individual_name=$(basename "$dir")

    # Read the individual AD result from the previously generated file
    if [ -f "$dir/RESULTADOS/RESULTADO_AD.txt" ]; then
        ad_value=$(cat "$dir/RESULTADOS/RESULTADO_AD.txt")
    else
        ad_value="No AD result found"
    fi

    # Read the individual AD left result
    if [ -f "$dir/RESULTADOS/RESULTADO_AD_ESQUERDO.txt" ]; then
        ad_left_value=$(cat "$dir/RESULTADOS/RESULTADO_AD_ESQUERDO.txt")
    else
        ad_left_value="No AD left result found"
    fi

    # Read the individual AD right result
    if [ -f "$dir/RESULTADOS/RESULTADO_AD_DIREITO.txt" ]; then
        ad_right_value=$(cat "$dir/RESULTADOS/RESULTADO_AD_DIREITO.txt")
    else
        ada_right_value="No AD right result found"
    fi

    # Append the individual's name and their AD values to the main result file
    echo "$individual_name: AD_total: $ad_value, AD_esquerdo: $ad_left_value, AD_direito: $ad_right_value" >> RESULTADOS/RESULTADOS_AD.txt
done




echo 'Obter valores médios de RD para toda a substância branca:'
#Obter a métrica de RD de cada indivíduo e salvar dentro da pasta do indivíduo
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_RD.nii -mask IN/PROCESSAMENTO/wm_reg.nii -output mean '>' IN/RESULTADOS/RESULTADO_RD.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_RD.nii -mask IN/PROCESSAMENTO/left_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_RD_ESQUERDO.txt
for_each $RAW_SUB/* : mrstats IN/MAPAS/MAPA_RD.nii -mask IN/PROCESSAMENTO/right_wm_reg.nii.gz -output mean '>' IN/RESULTADOS/RESULTADO_RD_DIREITO.txt
#Obter a métrica de RD de cada indivíduo e salvar em um único arquivo todos os valores de RD obtidos para cada indivíduo, no caso
for dir in $RAW_SUB/*; do
    # Extract the directory name (individual identifier)
    individual_name=$(basename "$dir")

    # Read the individual RD result from the previously generated file
    if [ -f "$dir/RESULTADOS/RESULTADO_RD.txt" ]; then
        rd_value=$(cat "$dir/RESULTADOS/RESULTADO_RD.txt")
    else
        rd_value="No RD result found"
    fi

    # Read the individual RD left result
    if [ -f "$dir/RESULTADOS/RESULTADO_RD_ESQUERDO.txt" ]; then
        rd_left_value=$(cat "$dir/RESULTADOS/RESULTADO_RD_ESQUERDO.txt")
    else
        rd_left_value="No RD left result found"
    fi

    # Read the individual RD right result
    if [ -f "$dir/RESULTADOS/RESULTADO_RD_DIREITO.txt" ]; then
        rd_right_value=$(cat "$dir/RESULTADOS/RESULTADO_RD_DIREITO.txt")
    else
        rd_right_value="No RD right result found"
    fi

    # Append the individual's name and their FA values to the main result file
    echo "$individual_name: RD_total: $rd_value, RD_esquerdo: $rd_left_value, RD_direito: $rd_right_value" >> RESULTADOS/RESULTADOS_RD.txt
done




for_each $RAW_SUB/* : rm -r IN/PROCESSAMENTO

######################################################################
#                     CHECAR DADOS COM ERRO              
######################################################################
#FUNÇÃO PARA CHECAR QUAIS DADOS NÃO FORAM GERADOS E INDIVÍDUOS COM PROBLEMAS NO PROCESSAMENTO
check_empty_files() {
    local directory="$1"

    # Check if the directory argument is provided and is not empty
    if [ -z "$directory" ]; then
        echo "Usage: check_empty_files <directory>"
        return 1
    fi

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "Error: '$directory' is not a valid directory."
        return 1
    fi

    # Use find command to locate text files (change '*.txt' to match your criteria)
    find "$directory" -type f -name '*.txt' | while IFS= read -r file; do
        # Check if the file is empty
        if [ ! -s "$file" ]; then
            echo "Empty file: $file"
        fi
    done > RESULTADOS/ERROR.txt  # Redirect all output to the 'ERROR' file
}

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory>"
    exit 1
fi

# Call the function with the provided directory argument
check_empty_files "$RAW_SUB"
