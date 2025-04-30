# Pipeline de Corregistro para o Espaço MNI

Este repositório contém um pipeline em **Bash** para realizar o corregistro de imagens de neuroimagem (T1 ponderado, DWI e rastreamento/tractografia) para o espaço padrão **MNI**, utilizando **FSL** e **MRtrix3**. O pipeline aceita como entrada arquivos DICOM brutos ou arquivos NIfTI pré-processados.

## Funcionalidades

- Coregistração de imagem T1 para o espaço MNI
- Registro de DWI (bruto ou pré-processado) via imagem T1
- Transformação de arquivos de rastreamento (.tck) para o espaço MNI
- Suporte a processamento em lote com execução paralela (`for_each`)
- Compatível com ferramentas populares de neuroimagem (FSL, MRtrix3, dcm2niix)

## Estrutura Esperada das Pastas

```
DIRETORIO_SUJEITO/ 
├── 3DT1/ 
│   └── Arquivos DICOM 
├── DTI/ 
│   └── Arquivos DICOM 
├── TRACKS/ 
│   └── Arquivos de tractografia (.tck) 
```

## Requisitos

- [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
- [MRtrix3](https://www.mrtrix.org/)
- [dcm2niix](https://github.com/rordenlab/dcm2niix)
- Comando `for_each` (disponível no MRtrix3 ou equivalente)

Certifique-se de que essas ferramentas estão no seu `PATH`.

## Instalação

Clone este repositório:
```bash
git clone https://github.com/seunomeusuario/mni-coregistration-pipeline.git
cd mni-coregistration-pipeline
```

## Uso

```bash
bash pipeline.sh <DIRETORIO_SUJEITO> <MODO>
```

### Modos Disponíveis

| Modo | Descrição                                   |
|------|---------------------------------------------|
| 1    | Coregistração da T1 para MNI               |
| 2    | Coregistração de DWI bruto (DICOM) para MNI |
| 3    | DWI pré-processado (NIfTI) para MNI         |
| 4    | Tractografia (.tck) para MNI                |

Exemplo:
```bash
bash pipeline.sh /caminho/para/sujeitos 1
```

## Saída

Os resultados serão salvos nas seguintes pastas:

```
IN/PROCESSAMENTO/     # Resultados intermediários
IN/MNI/               # Resultados finais no espaço MNI
```

## Agradecimentos

- [FMRIB Software Library (FSL)](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki)
- [MRtrix3](https://www.mrtrix.org/)
- [dcm2niix](https://github.com/rordenlab/dcm2niix)

## Contato

Em caso de dúvidas ou problemas:

**MSc. Hohana G. Konell**  
hohana.konell@alumni.usp.br
