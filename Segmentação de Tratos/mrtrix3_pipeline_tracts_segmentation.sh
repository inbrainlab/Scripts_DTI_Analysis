######################################################################
#                     Pipeline – Segmentação de Tractos                  
######################################################################

#Para rodar esse Pipeline é preciso ter instalado o software MRtrix3 e ter uma tractografia .tck no espaço MNI.
#Modo de uso: 

#Opção 1: Segmentação para tractografia com modelo de tensor (algoritmo determinístico, como FACT)
#$bash mrtrix3_pipeline.sh SUB 1

#Opção 2: Segmentação para tractografia com modelo CSD (algoritmo probabilístico, como iFOD2)
#$bash mrtrix3_pipeline.sh SUB 2

#SUB sendo as pastas com indivíduos, cada subpasta de cada individuo deve conter um diretorio obrigatório: MNI, com a respectiva tractografia .tck.
#Além de conter a pasta com as rois já definidas no mesmo diretório que estão a pasta com todos os indivíduos.
#Dessa forma a organizaçao de pastas seria:
#   ROIS/
#   SUB/
#      SUB_01/
#      SUB_02/
#       ...
#      SUB_N/
#            MNI/
#               tractografia_mni.tck


RAW_SUB=$1
PROCESS_METHOD=$2

if [ $# -ne 2 ]; then
    echo "Uso: bash pipeline.sh <SUBJECTS> <1-Segmentação com tractografia determinística (FACT, SD_STREAM, etc.) | 2-Segmentação com tractografia probabilística (iFOD2, iFOD2, etc.) >"
    exit 1
fi

# Check if the method argument is valid
if [[ "$PROCESS_METHOD" != "1" && "$PROCESS_METHOD" != "2" ]]; then
    echo "Escolha inválida. Use: (1) Segmentação com tractografia determinística (FACT, SD_STREAM, etc.) ou (2) Segmentação com tractografia probabilística (iFOD2, iFOD2, etc.)"
    exit 1
fi

for_each $RAW_SUB/* : mkdir IN/SEGMENTATIONS

if [[ "$PROCESS_METHOD" == "1" ]]; then
    echo 'Segmentação de tratos com tractografia determinística'
    echo 'Segmentação do trato Fascículo Uncinado (UF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/UF_R/ROI01.mif -include ROIS/UF_R/ROI02.mif IN/SEGMENTATIONS/UF_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/UF_L/ROI01.mif -include ROIS/UF_L/ROI02.mif IN/SEGMENTATIONS/UF_L.tck

    echo 'Segmentação do trato Fórnix (FX)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/FX_R/ROI01.mif -include ROIS/FX_R/ROI02.mif IN/SEGMENTATIONS/FX_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/FX_L/ROI01.mif -include ROIS/FX_L/ROI02.mif IN/SEGMENTATIONS/FX_L.tck

    echo 'Segmentação do trato Corticospinal (CST)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CST_R/ROI01.mif -include ROIS/CST_R/ROI02.mif -exclude ROIS/CST_R/NOT01.mif IN/SEGMENTATIONS/CST_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CST_L/ROI01.mif -include ROIS/CST_L/ROI02.mif -exclude ROIS/CST_L/NOT01.mif IN/SEGMENTATIONS/CST_L.tck

    echo 'Segmentação do trato Fascículo Inferior Fronto-Occipital (IFOF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/IFO_R/ROI01.mif -include ROIS/IFO_R/ROI02.mif -exclude ROIS/IFO_R/NOT01.mif -exclude ROIS/IFO_R/NOT02.mif IN/SEGMENTATIONS/IFO_R.tck
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/IFO_L/ROI01.mif -include ROIS/IFO_L/ROI02.mif -exclude ROIS/IFO_L/NOT01.mif  -exclude ROIS/IFO_L/NOT02.mif IN/SEGMENTATIONS/IFO_L.tck


    echo 'Segmentação do trato Fascículo Arqueado (ARC)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ARC/ROI01.mif  -include ROIS/ARC/ROI02.mif IN/SEGMENTATIONS/ARC_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ARC/ROI03.mif  -include ROIS/ARC/ROI04.mif IN/SEGMENTATIONS/ARC_L.tck -force

    echo 'Segmentação do trato Fascículo Superior Longitudinal (SLF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/SLF/ROI01.mif  -include ROIS/SLF/ROI02.mif -exclude ROIS/SLF/NOT01.mif IN/SEGMENTATIONS/SLF_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/SLF/ROI03.mif  -include ROIS/SLF/ROI04.mif -exclude ROIS/SLF/NOT01.mif IN/SEGMENTATIONS/SLF_L.tck -force

    echo 'Segmentação do trato Fascículo Inferior Longitudinal (ILF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ILF/ROI01.mif  -include ROIS/ILF/ROI02.mif -exclude ROIS/ILF/NOT01.mif IN/SEGMENTATIONS/ILF_R.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/ILF/ROI03.mif  -include ROIS/ILF/ROI04.mif -exclude ROIS/ILF/NOT01.mif IN/SEGMENTATIONS/ILF_L.tck -force   
    
    echo 'Segmentação do trato Cingulum (CGC)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CGC/ROI03.mif  -include ROIS/CGC/ROI04.mif IN/SEGMENTATIONS/CGC_R.tck -force 
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include ROIS/CGC/ROI01.mif  -include ROIS/CGC/ROI02.mif IN/SEGMENTATIONS/CGC_L.tck -force  

fi

if [[ "$PROCESS_METHOD" == "2" ]]; then
    echo 'Segmentação de tratos com tractografia probabilística'
    echo 'Segmentação do trato Fascículo Uncinado (UF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -21,29,-6,5  -include -34,-4,-14,6 -include -40,7,-30,6 -exclude -46,-12,-17,6 -exclude -17,51,9,7 -exclude -25,10,-44,3 -exclude -48,10,-44,5 -exclude -28,32,4,5 -exclude 0,28,4,5 -include -23,12,-9,5 IN/SEGMENTATIONS/UF_L.tck -force 
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 20,29,-7,6  -include 36,10,-31,6 -include 35,-1,-16,6 -exclude 16,58,4,8 -exclude 40,-11,-14,5 -exclude 41,-4,-34,5 IN/SEGMENTATIONS/UF_R.tck -force
   
    echo 'Segmentação do trato Fórnix (FX)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -0,-10,15,6  -include -17,-34,6,6 -include -29,-29,-8,6  -exclude -26,-48,18,6 -exclude -34,-50,-1,6 IN/SEGMENTATIONS/FX_L.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 7,-18,16,4  -include 17,-33,8,5  -include 31,-28,-8,5  -exclude 37,-49,0,6  IN/SEGMENTATIONS/FX_R.tck -force
    
    echo 'Segmentação do trato Corticospinal (CST)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -4,-34,-50,10 -include -13,-21,-15,10 -include -26,-21,14,10 -include -26,-24,38,15 -include -19,-28,56,15 -exclude -23,-53,49,10 -exclude -25,1,42,8 -exclude -51,-10,30,10 -exclude -42,-1,19,5 -exclude 9,-27,-31,10 -exclude -13,-52,-33,10 -exclude 6,-33,-33,10  IN/SEGMENTATIONS/CST_L.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 3,-31,-41,7 -include 13,-20,-13,7 -include 24,-16,13,10 -include 27,-16,33,15 -include 24,-16,56,15 -exclude 27,-42,38,8 -exclude -3,-4,26,6 -exclude 42,-4,25,5 -exclude 20,10,29,5 -exclude 22,-46,54,6 IN/SEGMENTATIONS/CST_R.tck -exclude -7,-33,-39,8 -exclude -42,-6,-24,10 -exclude 30,12,46,8 -exclude 15,-46,37,10 -exclude 47,-8,24,10 -exclude 16,-55,63,8 -exclude 21,14,37,5 -exclude 16,-47,-34,10 -force

    echo 'Segmentação do trato Fascículo Inferior Fronto-Occipital (IFOF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -21,26,1,10 -include -36,-9,-10,8 -include -30,-64,1,10 -exclude -5,23,5,12 IN/SEGMENTATIONS/IFO_L.tck -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 24,21,-4,10 -include 36,-11,-12,10 -include 27,-72,-1,10 IN/SEGMENTATIONS/IFO_R.tck -exclude 9,9,-7,8 -exclude 47,2,-29,12 -force

    echo 'Segmentação do trato Fascículo Arqueado (ARC)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -38,-12,26,6 -include -38,-35,27,6 -include -40,-50,2,8 IN/SEGMENTATIONS/ARC_L.tck -exclude ROIS/ARC/NOT_MTCSD.mif -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 35,-16,28,5 -include 36,-38,28,5 -include 41,-41,2,5 IN/SEGMENTATIONS/ARC_R.tck -exclude ROIS/ARC/NOT_MTCSD.mif -force

    echo 'Segmentação do trato Fascículo Superior Longitudinal (SLF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -39,-7,25,5 -include -39,-29,29,5 -include -39,-43,29,5 IN/SEGMENTATIONS/SLF_L.tck -exclude ROIS/SLF/NOT_MTCSD.mif -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 42,-5,28,5 -include 40,-29,33,5 -include 40,-50,31,5 IN/SEGMENTATIONS/SLF_R.tck -exclude ROIS/SLF/NOT_MTCSD.mif -force

    echo 'Segmentação do trato Fascículo Inferior Longitudinal (ILF)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -39,-6,-35,6 -include -41,-39,-7,6 -include -31,-76,3,8 IN/SEGMENTATIONS/ILF_L.tck -exclude -24,-61,19,15 -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 38,1,-28,6 -include 39,-36,-7,6 -include 24,-76,2,8 IN/SEGMENTATIONS/ILF_R.tck  -force

    echo 'Segmentação do trato Cingulum (CGC)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include -5,14,27,3  -include  -5,-8,33,3  -include -5,-34,30,3 IN/SEGMENTATIONS/CGC_L.tck -exclude ROIS/CGC/NOT_MTCSD.mif -force
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 8,17,20,3  -include 9,-9,32,3  -include 11,-35,29,3 IN/SEGMENTATIONS/CGC_R.tck -exclude ROIS/CGC/NOT_MTCSD.mif -force

    echo 'Segmentação do trato Comissura Anterior (AC)'
    for_each $RAW_SUB/* : tckedit IN/MNI/*.tck -include 0,2,-4,2 -include -14,2,-6,2 -include 12,4,-6,2 IN/SEGMENTATIONS/AC.tck -exclude -42,-42,4,8 -exclude 35,-42,4,8 -force
fi

echo 'Processamento concluído'