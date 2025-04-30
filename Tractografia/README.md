# MRtrix3 DWI Preprocessing and Tractography Pipeline

This is a full preprocessing and tractography pipeline for diffusion-weighted imaging (DWI) using [MRtrix3](https://www.mrtrix.org/), [FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/), and [ANTs](https://stnava.github.io/ANTs/).

---

## 📦 Requirements

Make sure the following software is installed and available in your environment's `PATH`:
- MRtrix3
- FSL
- ANTs
- `for_each` command from MRtrix3 scripting tools

---

## 📁 Folder Structure

The input folder (e.g., `SUB/`) should contain one subfolder per subject (e.g., `SUB_01`, `SUB_02`, ...), each structured as follows:

```
SUB/
├── SUB_01/
│   ├── DTI/      # Raw DWI DICOMs
│   ├── 3DT1/     # T1-weighted anatomical DICOMs
│   └── B0/       # (optional) Reverse-phase encoding B0 DICOMs
├── SUB_02/
│   └── ...
```

---

## 🚀 Usage

```bash
bash mrtrix3_pipeline.sh <SUB> <PROCESS_METHOD> <TRACTOGRAPHY_METHOD>
```

### Arguments:
- `<SUB>`: Path to folder containing subject directories
- `<PROCESS_METHOD>`:
  - `1` → Process without reversed-phase B0
  - `2` → Process with reversed-phase B0
- `<TRACTOGRAPHY_METHOD>`:
  - `1` → FACT (tensor-based tractography)
  - `2` → MTCSD (multi-tissue CSD)
  - `3` → Both methods

### Example:

```bash
bash mrtrix3_pipeline.sh ./SUB 2 3
```

---

## 🧠 Pipeline Steps

1. **DICOM Conversion**  
   Convert DWI and T1 images from DICOM to NIfTI or MRtrix formats.

2. **Denoising and Gibbs Artifact Correction**  
   Use `dwidenoise` and `mrdegibbs`.

3. **Preprocessing**  
   Eddy-current and susceptibility distortion correction:
   - With B0 reversed phase: uses `dwifslpreproc -rpe_pair`
   - Without B0 reversed phase: uses `dwifslpreproc -rpe_none`

4. **Bias Field Correction**  
   Performed with `dwibiascorrect ants`.

5. **Registration**  
   - Skull stripping with FSL BET
   - Linear registration of T1 to DWI using FSL FLIRT
   - Matrix conversion and transformation with MRtrix

6. **Tissue Segmentation**  
   Segmentation via `5ttgen fsl` for ACT-based tractography.

7. **Mask Creation**  
   Generate DWI brain mask with `dwi2mask`.

8. **Tractography**
   - **FACT**:
     - Tensor fitting, metric extraction, streamline generation
   - **MTCSD**:
     - Response function estimation (Dhollander)
     - FOD computation
     - iFOD2 probabilistic tractography

---

## ✅ Output

Each subject folder will contain a `PROCESSAMENTO/` directory with intermediate and final outputs, including:
- Preprocessed DWI (`dwi_bias.mif`)
- Brain mask (`dwi_mask.mif`)
- Segmentation (`5ttseg.nii`)
- Tractography output (`FACT.tck`, `MTCSD.tck`)

---

## 📌 Notes

- This script assumes consistent acquisition parameters across subjects.
- Customize `pe_dir` if your phase encoding direction differs (`AP`, `PA`, etc.).
- Adjust memory/thread usage in `for_each` for performance tuning.

---

## 🧑‍💻 Author

Developed and maintained by [Your Name / Lab].

---
