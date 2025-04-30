#!/bin/bash
########################################################################
#                Pipeline – Segmentação de Tratos com MRtrix3         #
#                                                                      #
# Descrição:                                                           #
#     Este script realiza a segmentação de tratos cerebrais com base  #
#     em tractografias no espaço MNI, utilizando o MRtrix3. Ele       #
#     oferece suporte à segmentação baseada em modelos de             #
#     tractografia determinística e probabilística.                   #
#                                                                      #
# Requisitos:                                                          #
#     - MRtrix3 instalado                                              #
#     - Tractografia (.tck) no espaço MNI para cada sujeito            #
#     - Diretório com ROIs (.mif) já definidas                         #
#                                                                      #
# Organização esperada dos diretórios:                                #
#   ROIS/                                                              #
#   SUB/                                                               #
#     └── SUB_01/                                                      #
#         └── MNI/tractografia_mni.tck                                 #
#     └── SUB_02/                                                      #
#         └── MNI/tractografia_mni.tck                                 #
#     ...                                                              #
#                                                                      #
# Uso:                                                                 #
#     bash mrtrix3_pipeline.sh <CAMINHO_PARA_SUB> <1|2>                #
#         1 → Segmentação com tractografia determinística (FACT, etc.)#
#         2 → Segmentação com tractografia probabilística (iFOD2, etc.)#
########################################################################

# Entrada dos argumentos
RAW_SUB=$1
PROCESS_METHOD=$2

# Verificação dos argumentos
if [ $# -ne 2 ]; then
    echo "Uso: bash mrtrix3_pipeline.sh <SUBJECTS_DIR> <1-determinístico | 2-probabilístico>"
    exit 1
fi

# Verifica se o método selecionado é válido
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" ]]; then
    echo "Método inválido. Escolha: 1 (determinístico) ou 2 (probabilístico)"
    exit 1
fi

# Criação da pasta de segmentações para cada sujeito
for_each $RAW_SUB/* : mkdir -p IN/SEGMENTATIONS

# ====================== MÉTODO 1: DETERMINÍSTICO ======================
if [[ "$PROCESS_METHOD" == "1" ]]; then
    echo 'Iniciando segmentação com tractografia determinística...'

    ## Fascículo Uncinado (UF)
    echo 'Segmentando UF...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/UF_R/ROI01.mif -include ROIS/UF_R/ROI02.mif IN/SEGMENTATIONS/UF_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/UF_L/ROI01.mif -include ROIS/UF_L/ROI02.mif IN/SEGMENTATIONS/UF_L.tck

    ## Fórnix (FX)
    echo 'Segmentando Fórnix...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/FX_R/ROI01.mif -include ROIS/FX_R/ROI02.mif IN/SEGMENTATIONS/FX_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/FX_L/ROI01.mif -include ROIS/FX_L/ROI02.mif IN/SEGMENTATIONS/FX_L.tck

    ## Trato Corticoespinal (CST)
    echo 'Segmentando CST...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CST_R/ROI01.mif -include ROIS/CST_R/ROI02.mif -exclude ROIS/CST_R/NOT01.mif IN/SEGMENTATIONS/CST_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CST_L/ROI01.mif -include ROIS/CST_L/ROI02.mif -exclude ROIS/CST_L/NOT01.mif IN/SEGMENTATIONS/CST_L.tck

    ## Fascículo Inferior Fronto-Occipital (IFOF)
    echo 'Segmentando IFOF...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/IFO_R/ROI01.mif -include ROIS/IFO_R/ROI02.mif -exclude ROIS/IFO_R/NOT01.mif -exclude ROIS/IFO_R/NOT02.mif IN/SEGMENTATIONS/IFO_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/IFO_L/ROI01.mif -include ROIS/IFO_L/ROI02.mif -exclude ROIS/IFO_L/NOT01.mif  -exclude ROIS/IFO_L/NOT02.mif IN/SEGMENTATIONS/IFO_L.tck

    ## Fascículo Arqueado (ARC)
    echo 'Segmentando ARC...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ARC/ROI01.mif  -include ROIS/ARC/ROI02.mif IN/SEGMENTATIONS/ARC_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ARC/ROI03.mif  -include ROIS/ARC/ROI04.mif IN/SEGMENTATIONS/ARC_L.tck -force

    ## Fascículo Longitudinal Superior (SLF)
    echo 'Segmentando SLF...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/SLF/ROI01.mif  -include ROIS/SLF/ROI02.mif -exclude ROIS/SLF/NOT01.mif IN/SEGMENTATIONS/SLF_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/SLF/ROI03.mif  -include ROIS/SLF/ROI04.mif -exclude ROIS/SLF/NOT01.mif IN/SEGMENTATIONS/SLF_L.tck -force

    ## Fascículo Longitudinal Inferior (ILF)
    echo 'Segmentando ILF...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ILF/ROI01.mif  -include ROIS/ILF/ROI02.mif -exclude ROIS/ILF/NOT01.mif IN/SEGMENTATIONS/ILF_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ILF/ROI03.mif  -include ROIS/ILF/ROI04.mif -exclude ROIS/ILF/NOT01.mif IN/SEGMENTATIONS/ILF_L.tck -force   

    ## Cíngulo (CGC)
    echo 'Segmentando CGC...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CGC/ROI03.mif  -include ROIS/CGC/ROI04.mif IN/SEGMENTATIONS/CGC_R.tck -force 
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CGC/ROI01.mif  -include ROIS/CGC/ROI02.mif IN/SEGMENTATIONS/CGC_L.tck -force  
fi

# ===================== MÉTODO 2: PROBABILÍSTICO =======================
if [[ "$PROCESS_METHOD" == "2" ]]; then
    echo 'Iniciando segmentação com tractografia probabilística...'
    echo 'Nota: Coordenadas espaciais usadas diretamente como inclusões/exclusões'

    ## Exemplos a seguir seguem o mesmo padrão:
    ## -include <x,y,z,r> : ROI esférica centrada em x,y,z com raio r
    ## -exclude <x,y,z,r> : região a ser excluída
    ## -force : sobrescreve arquivos se já existentes

    ## Fascículo Uncinado (UF)
    echo 'Segmentando UF...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -21,29,-6,5  -include -34,-4,-14,6 -include -40,7,-30,6 -exclude -46,-12,-17,6 ... IN/SEGMENTATIONS/UF_L.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 20,29,-7,6  -include 36,10,-31,6 -include 35,-1,-16,6 ... IN/SEGMENTATIONS/UF_R.tck -force

    ## (...seguir com os demais tratos com mesma lógica...)

    ## Comissura Anterior (AC)
    echo 'Segmentando Comissura Anterior...'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 0,2,-4,2 -include -14,2,-6,2 -include 12,4,-6,2 -exclude -42,-42,4,8 -exclude 35,-42,4,8 IN/SEGMENTATIONS/AC.tck -force
fi

# Finalização
echo 'Segmentação concluída com sucesso!'
