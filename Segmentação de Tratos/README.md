
# MRtrix3 Tract Segmentation Pipeline

Este pipeline realiza a segmentação de feixes de substância branca a partir de uma tractografia no espaço MNI usando o software MRtrix3.

## Pré-requisitos

- [MRtrix3](https://www.mrtrix.org/) instalado e configurado
- Tractografia `.tck` no espaço MNI para cada sujeito
- Diretório com ROIs nomeados corretamente

## Organização do Diretório

```
.
├── ROIS/
├── SUB/
│   ├── SUB_01/
│   │   └── MNI/
│   │       └── tractografia_mni.tck
│   ├── SUB_02/
│   │   └── MNI/
│   │       └── tractografia_mni.tck
│   └── ...
```

## Como usar

```bash
bash mrtrix3_pipeline.sh <CAMINHO_PARA_SUB> <MÉTODO>
```

- `<CAMINHO_PARA_SUB>`: Diretório contendo as subpastas de cada sujeito (ex: `SUB`)
- `<MÉTODO>`:
  - `1` – Segmentação com tractografia **determinística** (ex: FACT, SD_STREAM)
  - `2` – Segmentação com tractografia **probabilística** (ex: iFOD2)

### Exemplo

```bash
bash mrtrix3_pipeline.sh SUB 1
```

## Feixes Segmentados

Este pipeline realiza a segmentação dos seguintes tratos:

- Fascículo Uncinado (UF)
- Fórnix (FX)
- Corticospinal (CST)
- Fascículo Inferior Fronto-Occipital (IFOF)
- Fascículo Arqueado (ARC)
- Fascículo Superior Longitudinal (SLF)
- Fascículo Inferior Longitudinal (ILF)
- Cingulum (CGC)
- Comissura Anterior (AC) *(apenas para método 2)*

## Observações

- Segmentações com método 1 usam ROIs `.mif`.
- Segmentações com método 2 usam coordenadas MNI.
- O diretório `IN/SEGMENTATIONS` será criado dentro de cada sujeito para armazenar os arquivos `.tck` segmentados.

## Licença

Este projeto está licenciado sob os termos da licença MIT.
