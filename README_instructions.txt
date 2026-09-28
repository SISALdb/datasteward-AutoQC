SISAL v15 Workbook QC — Data Steward Instructions
===================================================
Last updated: June 2026


OVERVIEW
--------
When a contributor sends you a filled SISAL v15 workbook, run two steps:

  Step 1 — Python QC script (wb_check_v15.py)
           Validates the workbook content and structure, including a U-Th
           age credibility check (Section 8, added June 2026). Produces a
           QC log, a site map, and — if no errors are found — a QC-passed
           copy of the workbook, all saved to the Output/ folder.

  Step 2 — R plotting script (run_plots.R)
           Generates a PDF per entity with age model, possible hiatus, and
           proxy time-series plots. Saved to the Output/ folder.

Note: the Julia U-Th script (sisal2_read.jl) is no longer needed as a
separate step. Its checks are now integrated into Step 1 (Section 8).

Both scripts must be run from the datasteward-AutoQC/ folder (the repo root).


FOLDER STRUCTURE
----------------
datasteward-AutoQC/
  wb_check_v15.py               Python QC script
  run_plots.R                   R plotting runner
  plot_agemodels_hiatus.R       R plotting library (do not edit)
  Filled_SISAL_Workbook_v15/    <-- put contributor workbooks here
  Output/                       <-- all outputs are written here
  Legacy/                       old script versions (for reference only)


ONE-TIME SETUP
--------------
Python packages required (install once with pip or conda):
  pandas, numpy, openpyxl, xlrd, matplotlib, cartopy, shapely, scipy

  pip install pandas numpy openpyxl xlrd matplotlib cartopy shapely scipy

R packages required (install once in R or RStudio):
  openxlsx, ggplot2

  install.packages(c("openxlsx", "ggplot2"))


HOW TO RUN — STEP BY STEP
--------------------------

Before you start:
  - Copy the contributor's .xlsx file into the Filled_SISAL_Workbook_v15/ folder.
  - Make sure the file is closed in Excel.
  - Open a terminal (Mac: Terminal app; Windows: Anaconda Prompt or PowerShell).
  - Navigate to the datasteward-AutoQC/ folder:
      cd "/path/to/datasteward-AutoQC"

--- Step 1: Python QC check ---

Run:
  python wb_check_v15.py SISAL_workbook_v15_SiteName_EntityName.xlsx

The script will:
  - Print all warnings and informative messages to the terminal AND save them
    automatically to Output/QC_log_<filename>.txt
  - Save a regional site map to Output/map_<filename>.png
  - If 0 warnings: copy a QC-passed workbook to Output/QC_passed_<filename>.xlsx

Read the QC log carefully. Warnings (counted in the final line) must be fixed
by the contributor before proceeding. Informative messages do not block the QC
but should be reviewed.

If there are warnings, send the QC log to the contributor with instructions to
correct the issues and resubmit. Once corrected:
  - Replace the file in Filled_SISAL_Workbook_v15/ with the updated version.
  - Re-run the Python script.
  - Repeat until the log reports "0 warning/s were detected".

--- Step 2: R age-model plots ---

Once Step 1 passes (0 warnings), run:
  Rscript run_plots.R SISAL_workbook_v15_SiteName_EntityName.xlsx

Or, if you prefer RStudio:
  - Open run_plots.R in RStudio.
  - At the very bottom of the file, set xls <- "SISAL_workbook_v15_SiteName_EntityName.xlsx"
    and source the file (Ctrl+Shift+S / Cmd+Shift+S).
  - Make sure your working directory is set to the datasteward-AutoQC/ folder
    (Session > Set Working Directory > To Source File Location).

The script produces:
  Output/QC_agemodel_hiatus_<SiteName>_<EntityName>.pdf

Each PDF has 10 pages per entity:
  Page 1  — Age model (depth vs. age, U/Th dates with error bars, hiatuses)
  Page 2  — Interp_age difference between consecutive samples vs. depth
             (large spikes not at hiatuses may indicate missing hiatus markers)
  Page 3  — d18O vs time
  Page 4  — d13C vs time
  Pages 5-10 — Sr/Ca, Mg/Ca, Ba/Ca, U/Ca, P/Ca, Sr isotopes vs time
             (blank page shown if a proxy is not present in the workbook)

Check the plots visually:
  - Does the age model look continuous and physically plausible?
  - Are there large age jumps on page 2 that are not marked as hiatuses?
    If yes, ask the contributor to add a hiatus entry and rerun from Step 1.
  - Do the isotope and trace-element time series look reasonable?


OUTPUT FILES SUMMARY
--------------------
After a successful run, the Output/ folder will contain:

  QC_log_<filename>.txt          Full QC log from Step 1
  map_<filename>.png             Regional site map (±15° around site)
  QC_passed_<filename>.xlsx      Workbook copy confirming QC passed
  QC_agemodel_hiatus_<...>.pdf   Age model and proxy plots from Step 2


SUBMITTING TO THE DATABASE
--------------------------
Once both steps are complete and the plots look good:
  - Send QC_passed_<filename>.xlsx and QC_agemodel_hiatus_<...>.pdf
    to the SISAL database manager.
  - Keep the QC_log and map as documentation.


TROUBLESHOOTING
---------------
"Cannot read in excel file"
  -> Check the filename is spelled exactly right (case-sensitive on Mac/Linux).
  -> Make sure the file is in Filled_SISAL_Workbook_v15/ and not in Output/.

"This workbook is likely not version 15"
  -> The contributor submitted a v14 or older workbook. Ask them to use the
     current v15 template (SISAL_workbook_v15_template.xlsx).

"Error in source('plot_agemodels_hiatus.R')" in R
  -> Make sure your working directory is the datasteward-AutoQC/ folder,
     not a subfolder.

Python warnings about openpyxl or cartopy appearing in the terminal
  -> These are suppressed automatically. If they still appear, run as:
     python -W ignore wb_check_v15.py <filename.xlsx>

"Warning (U-Th check, EntityName): 234U/238U activity ratio <= 0"
  -> The contributor has submitted d234U instead of the 234U/238U activity
     ratio. Ask them to convert: activity ratio = 1 + d234U / 1000.

"Warning (U-Th check, EntityName): ini_230Th/232Th mean < 0.01"
  -> The initial 230Th/232Th value appears to be an atomic ratio (e.g. the
     default 4.4 × 10⁻⁶) instead of the required activity ratio (~0.818
     for the bulk Earth assumption). Ask contributor to check the workbook
     instructions for the correct value.

"Warning (U-Th check, EntityName): Recalculated ages deviate X% from reported"
  -> The isotope data submitted does not reproduce the reported ages when
     recalculated independently. Most common causes:
       1. d234U submitted instead of 234U/238U activity ratio
       2. ini_230Th/232Th given as atomic ratio instead of activity ratio
       3. Wrong half-lives used by the original lab software
     Ask the contributor to verify their isotope inputs against the
     workbook instructions.
