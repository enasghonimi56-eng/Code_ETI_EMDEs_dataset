# Code_ETI_EMDEs_dataset
STATA and Python scripts for constructing the Energy Transition Index (ETI) 
for Emerging Market and Developing Economies (EMDEs), 2000–2023.

## Contents

| File | Description |
|---|---|
| `ETI Construction and Sensitivity Analysis.do` | Data preparation, missing-data imputation (MICE-PMM), and construction of the ETI and its sub-indices, plus sensitivity analysis |
| `Fig. 2 Spatial distribution of ETI.py` | Generates the ETI world maps (Figure 2) |
| `Fig. 3 Sensitivity analysis.py` | Generates the sensitivity analysis figure (Figure 3) |
| `Fig. 4 ETI by WB income group.py` | Generates the income-group comparison figure (Figure 4) |
| `Fig. 5 ETI by Region.py` | Generates the regional comparison figure (Figure 5) |
| `Fig. 6 Comparison with WEF-ETI.py` | Generates the comparison with the WEF-ETI 2025 (Figure 6) |

## How to run

1. Place the raw indicator file inside a `Data/` subfolder (see the `.do` file header for details). This raw file is not included in the repository; all indicator sources are listed in the paper.
2. Run the `.do` file in Stata 15+ to reproduce the ETI construction and sensitivity analysis.
3. Run each Python script in Google Colab (or a local Python environment) to reproduce the corresponding figure.

## Data

The constructed ETI dataset is published separately on Figshare: [DOI link here]

## Citation

If you use this code, please cite the associated paper 
(currently under review):

Ghonimi, E., & Sun, Y. A dataset of the energy transition index for emerging market and developing economies from 2000 to 2023. 
Manuscript submitted for publication, Scientific Data.

You may also cite this code repository directly:

Ghonimi, E., & Sun, Y. Code_ETI_EMDEs_dataset. GitHub repository. 
https://github.com/enasghonimi56-eng/Code_ETI_EMDEs_dataset
