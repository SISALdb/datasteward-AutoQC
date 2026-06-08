# datasteward-AutoQC

Pre-upload quality control scripts for SISAL v15 workbooks submitted to the SISAL-Neotoma database.

## What this repo contains

| File | Purpose |
|------|---------|
| `wb_check_v15.py` | Python QC script — validates workbook structure, vocabularies, isotope data, and U-Th age credibility |
| `run_plots.R` | R script — generates age model and proxy time-series plots per entity |
| `plot_agemodels_hiatus.R` | R plotting library used by `run_plots.R` (do not edit directly) |
| `Filled_SISAL_Workbook_v15/` | Put contributor workbooks here before running |
| `Output/` | All outputs are written here |
| `Legacy/` | Older script versions for reference only |

## Quick start

See `README_instructions.txt` for full step-by-step instructions.

**One-time setup:**
```bash
pip install pandas numpy openpyxl xlrd matplotlib cartopy shapely scipy
```
```r
install.packages(c("openxlsx", "ggplot2"))
```

**Run:**
```bash
python wb_check_v15.py SISAL_workbook_v15_SiteName_EntityName.xlsx
Rscript run_plots.R SISAL_workbook_v15_SiteName_EntityName.xlsx
```

## What the Python script checks

The script is structured in 11 sections. Key checks:

| Section | What it checks |
|---------|---------------|
| 3 | Workbook version / column schema |
| 7.i | Site metadata (coordinates, elevation, site name) |
| 7.ii | Entity metadata (dropdowns, ORCID format, DOI, trace element flags) |
| 7.ii.b | References (citation, DOI, no placeholder text) |
| 7.iii | Sample data (depths, isotopes, age model, trace elements, depth ordering) |
| 7.iii.d + 8 old | Dating information (U/Th, C14, laminations, hiatuses) |
| 7.iii.e | Lamina age vs depth |
| **8 (new)** | **U-Th age credibility check** — recalculates ages from isotope ratios and compares to reported values |
| 9 | Summary of unknowns |
| 10 | QC result + QC-passed workbook copy |
| 11 | Site location map |

### U-Th age credibility check (Section 8)

Added June 2026. Ported from `sisal2_read.jl` (Fohlmeister, QC_SISALv2_dating_metadata).

For each entity with U-Th dates, the script:
- Detects ratio-type errors: d234U submitted instead of activity ratio, atomic ratios instead of activity ratios for `230Th/232Th` and `ini_230Th/232Th`
- Independently recalculates uncorrected and detrital-corrected ages from submitted isotope data using the U-Th ingrowth equation (Brent's method solver, Monte Carlo 2σ error propagation)
- Flags if recalculated ages deviate > 1% (uncorrected) or > 5% (corrected) from reported values
- Supports 3 pathways for uncorrected ages and 5 pathways for corrected ages, depending on which isotope ratios/concentrations are available
- Decay constants: Cheng et al. 2013 (default), Cheng et al. 2000, Edwards et al. 1987

## Authors

K. Atsawawaranunt · L. Comas-Bru · E. Pestalozzi · I. Hatvani · L. Endres

U-Th check ported from Julia original by J. Fohlmeister.
