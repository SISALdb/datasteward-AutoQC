# SISAL Workbook QC Script — Summary and Web Migration Notes

**Script:** `wb_check_v12_compatible.py`  
**Target workbook version:** SISAL v15  
**Authors:** K. Atsawawaranunt, E. Pestalozzi, I. Hatvani, L. Endres  
**Date of this document:** April 2026

---

## 1. Purpose

The script validates a contributor-submitted Excel workbook before it is ingested into the SISAL (Speleothem Isotopes Synthesis and Analysis) database. It checks that the data are internally consistent, that all required fields are filled, that values belong to controlled vocabularies (dropdown lists), and that measurements and ages fall within physically plausible ranges. The script outputs a human-readable log of all warnings, a regional site map, and — if no warnings are raised — copies the workbook with a `QC_passed_` prefix.

---

## 2. Workbook Structure

A valid SISAL v15 workbook is a single `.xlsx` file containing six named sheets:

| Sheet | Key columns |
|---|---|
| **Site metadata** | site_name, latitude, longitude, elevation, monitoring |
| **Entity metadata** | entity_name, speleothem_type, drip_type, mineralogy/petrology, trace-element method flags, contact, contact_orcid, data_DOI_URL |
| **References** | entity_name, citation, publication_DOI |
| **Dating information** | entity_name, date_type, corr_age ± uncertainties, material_dated, calib_used, date_used, chem_year |
| **Lamina age vs depth** | entity_name, depth_lam, lam_age ± uncertainties |
| **Sample data** | entity_name, depth_sample, hiatus/gap, mineralogy, interp_age ± uncertainties, age_model_type, d13C/d18O measurements + precisions, six trace-element measurement/precision pairs |

---

## 3. What the Script Checks

The script is structured in ten numbered sections. The substantive checks are in sections 3–9.

### 3.1 Version check (Section 3)
Compares the column names of each sheet against the expected v15 schema. Any missing column triggers an immediate exit, because subsequent checks depend on the full schema being present.

### 3.2 Site metadata (Section 7.i)
- Latitude in [−90, 90] and longitude in [−180, 180]; exactly one row of coordinates.
- Coordinates appear to fall on land (cartopy Natural Earth 110 m resolution; informative only).
- Elevation is numeric when present.
- site_name does not start or end with a space.
- `monitoring` value belongs to the controlled vocabulary.

### 3.3 Entity metadata (Section 7.ii)
- All required fields present and non-empty.
- All yes/no/not known fields use the correct vocabulary.
- `speleothem_type`, `drip_type`, geology, rock age, vegetation type, land use, cover type, and related fields validated against dropdown lists.
- `drip_type` must be empty for composite entities and non-empty for non-composites.
- `contact_orcid` format validated: must be four groups of four digits separated by dashes (XXXX-XXXX-XXXX-XXXX), with the checksum digit accepted.
- `data_DOI_URL` must start with `http`, `10.`, or `ftp`; cannot equal `publication_DOI`.

### 3.4 References (Section 7.ii.b)
- Citation and publication_DOI fields are present and non-empty for every entity.
- `publication_DOI` starts with `http`, `10.`, or equals `unpublished`.
- No field contains placeholder text ("unknown", "not applicable", "na", "n/a", "none").

### 3.5 Sample data (Section 7.iii)
This is the largest section. Checks are applied in layers, where later checks are only attempted if earlier ones pass.

**Structural and type checks:**
- No repeated `depth_sample` within an entity.
- `hiatus` and `gap` columns contain only allowed codes.
- `mineralogy` and `arag_corr` validated against dropdown lists (applies to composites too).

**Isotope measurement/precision co-existence:**
- d13C and d18O: measurement must be present if precision is, and vice versa.
- Six trace-element pairs (Sr_Ca, Mg_Ca, Ba_Ca, U_Ca, P_Ca, Sr_isotopes): checked as informative-only; if mismatched, the specific mismatched pair names are printed.

**Age model checks:**
- `interp_age` is numeric and within [−70, 800 000] BP (covering the practical U/Th limit).
- `interp_age_uncert_pos/neg` are positive numbers when present.
- `age_model_type` and `ann_lam_check` validated against dropdown lists.
- Entities with all-missing `interp_age` are flagged as missing an age model.

**Depth ordering (per entity):**
- The script auto-detects whether depth is measured from top or from base by computing the mean of Δ(interp_age) over depth-sorted samples.
  - mean Δ > 0 → from top; mean Δ < 0 → from base; ambiguous → ordering check skipped.
- The inferred direction is printed as an informative message.
- Ages and depths are then checked to increase/decrease monotonically in the expected direction.
- Possible missing hiatuses are flagged when an age gap ≥ 5× the mean step is found without a hiatus marker between those depths.

**Composite entities:**
- Gap column usage validated.
- `interp_age` range checked (same [−70, 800 000] bounds).

### 3.6 Dating information (Section 7.iii.d and 8)
- All required columns present per date type (U/Th, C14, lamination events, hiatuses).
- `corr_age` within [−70, 800 000] BP for dates marked `date_used = yes/unknown`.
- `calib_used`, `material_dated`, `decay_constant` validated against dropdown lists.
- No hiatuses share a `depth_dating` value with a non-hiatus date.
- Dates for "Event; actively forming" flagged if `corr_age > 0` (older than 1950 BP).
- Completeness: required fields not empty when `date_used ≠ no`.
- Lamination integrity: start-of-laminations event precedes end-of-laminations in depth; end-of-laminations `corr_age ≤ 0` (modern).

### 3.7 Lamina age vs depth (Section 7.iii.e)
- `lam_age` numeric and within [−70, 800 000] BP.
- `lam_age_uncert_pos/neg` are positive numbers.
- No repeated depths within an entity.

### 3.8 Global whitespace sanitisation (pre-check)
Before any checks run, all string columns in all six tables are stripped of non-breaking spaces (`\xa0`) and leading/trailing whitespace. This prevents silent dropdown mismatches caused by Excel copy-paste artefacts.

### 3.9 Outputs
| Output | Condition |
|---|---|
| Warning log (stdout / redirected `.txt`) | Always |
| `QC_passed_<filename>.xlsx` | Zero warnings only |
| `map_<filename>.png` | Always (wrapped in try/except) |

The site map is a ±15° regional PlateCarree plot with Natural Earth land, ocean, coastline, borders, lakes, and rivers; the site is marked with a red star and labelled.

---

## 4. Migration to a Web Version

### 4.1 What stays the same
All of the actual QC logic — every function and every check — can be reused as-is. The checking code is pure Python/pandas and has no dependency on the filesystem path or the CLI invocation model. The only parts that need to change are **how the file is delivered** (upload instead of CLI argument) and **how results are presented** (HTML/JSON instead of stdout).

### 4.2 Recommended architecture

**Back end — Python, Flask or FastAPI**  
The script is most naturally wrapped as a single REST endpoint that accepts an uploaded `.xlsx` file, runs the checks in memory, and returns a structured JSON response containing a list of warnings (with sheet name, field, row, and message) plus base64-encoded map image and optionally the `QC_passed_` file for download.

Suggested refactor of the script internals:
1. Replace `print(...)` throughout with `warnings_list.append({...})` — capture sheet, field, row, message, and severity (warning vs. informative).
2. Wrap the whole body in a function `run_qc(xlsx_bytes) -> dict` that accepts the file as bytes and returns the structured result.
3. Keep `shutil.copy` for the CLI path; for the web path, return the passed file as bytes.

**Front end — React or plain HTML**  
A minimal UI needs only: a file-upload input, a submit button, a results panel (tabular list of warnings grouped by sheet), a map image display, and a download button for the passed workbook. An alternative or complement is an online form that lets contributors fill in fields directly and submits structured data — but this is significantly more work (see 4.3).

**Deployment**  
A containerised deployment (Docker) is the simplest path: the back end container includes Python, pandas, openpyxl, cartopy, and shapely; the front end can be a separate static build or served by the same container. The stateless design (upload → process → respond → discard) means no database is needed for the QC service itself.

### 4.3 The online form option
Allowing contributors to fill in data directly in the browser (rather than uploading an Excel file) requires building a dynamic multi-sheet form that mirrors the v15 workbook schema exactly. This is substantially more effort than the upload-and-validate path, but it has the advantage of providing real-time per-field validation. A pragmatic middle ground is to offer both: upload for experienced contributors, and a guided form as an onboarding tool that ultimately exports a valid `.xlsx` for offline archiving.

### 4.4 Key technical considerations

| Topic | Note |
|---|---|
| **File size** | SISAL workbooks are typically small (<5 MB); no streaming needed. |
| **Cartopy / shapely on server** | Both are available via pip/conda; the Natural Earth shapefiles download automatically on first use and can be pre-baked into the Docker image to avoid runtime network calls. |
| **Concurrency** | The QC function is CPU-bound but fast (<2 s). A single-worker deployment handles one submission at a time; for higher load, use a task queue (Celery + Redis) and return a job ID with polling. |
| **Security** | The uploaded file is only opened by pandas/openpyxl; no shell execution occurs. Validate MIME type and file extension server-side; set a file-size limit; never persist the raw upload. |
| **Output format** | Returning structured JSON (list of `{sheet, field, row, severity, message}` objects) is more useful than plain text for the front end, and is trivially derived from the refactored `warnings_list`. |
| **Versioning** | The version check (Section 3) should remain as the first gate; future workbook versions would need a version-specific validation module behind a version-dispatch layer. |
