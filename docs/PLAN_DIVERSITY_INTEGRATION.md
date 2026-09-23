# Plan: Diversity Analysis Integration into vcftocounts

## Overview

Integrates Files2Tuebingen's diversity analysis pipeline (Hill numbers, ANOVA, permutation tests, plots) into the vcftocounts nf-core pipeline. This enables comparison of VCF sets coming from different pipelines (e.g., freebayes, strelka, gatk) by analyzing genetic diversity patterns across them.

## Files2Tuebingen Analysis Pipeline

The Files2Tuebingen pipeline (in `/home/ubuntu/working/Files2Tuebingen/R/`) performs diversity analysis:
- **main.R** (497 lines): Orchestrator running full pipeline
- **data_io.R** (175 lines): `load_and_preprocess_data()` - loads and preprocesses CSV files
- **hill_calculations.R** (1875 lines): Hill number calculations with Monte Carlo simulation
- **variance_analysis.R** (2294 lines): ANOVA, permutation tests, variance decomposition
- **plotting.R** (1075 lines): Diagnostic plots generation
- **utils.R** (79 lines): Helper utilities

## Integration Architecture

```
VCF/gVCF files (multiple pipelines via pipeline_name column)
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  EXISTING PIPELINE (unchanged):                         │
│  tabix → GATK → filter → concat → reheader → merge     │
│  → annotate → vcf2counts.R (genotype matrix 0/1/2)     │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  NEW: CSV CONVERSION MODULE                              │
│  Converts 0/1/2 wide matrix → long-format CSVs          │
│  Output: filtered_counts.csv, null_counts.csv           │
│  Format: variant_called, sample_name, pipeline, genotype│
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  NEW: DIVERSITY ANALYSIS MODULES (m01-m07)              │
│                                                         │
│  m01: prepare_data                                       │
│    Wraps: load_and_preprocess_data() from data_io.R     │
│    Input: filtered_csv, null_csv, demo_info             │
│    Output: prepared.RData + prepared_summary.csv        │
│                                                         │
│  m02: null_hill (Monte Carlo stage)                     │
│    Wraps: calculateNullHill() from hill_calculations.R  │
│    Input: prepared.RData, demo_info                     │
│    Output: nullhill.RData + chunks/                     │
│    Heavy process - uses hillR, future, future.apply     │
│                                                         │
│  m03: filtered_hill                                      │
│    Wraps: calculate_filtered_hill() from                │
│            hill_calculations.R                           │
│    Input: prepared.RData, nullhill.RData                │
│    Output: filteredhill.RData                           │
│                                                         │
│  m04: pipeline_differences                              │
│    Wraps: analyze_pipeline_differences() from           │
│            variance_analysis.R                           │
│    Input: nullhill.RData                                │
│    Output: anova/*.csv (permutation test results)       │
│                                                         │
│  m05: filtered_vs_null                                  │
│    Wraps: compare_pipeline_patterns() from              │
│            variance_analysis.R                           │
│    Input: nullhill.RData, filteredhill.RData            │
│    Output: patterns/*.csv                               │
│                                                         │
│  m06: variance_decomposition                            │
│    Wraps: analyze_variance_decomposition() from         │
│            variance_analysis.R                           │
│    Input: nullhill.RData                                │
│    Output: variance.RData                               │
│                                                         │
│  m07: plots                                             │
│    Wraps: generate_all_plots() from plotting.R          │
│    Input: nullhill.RData, filteredhill.RData            │
│    Output: plots/*.pdf, plots/*.csv                     │
│                                                         │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  MULTIQC (extended):                                    │
│  Add diversity summaries, plots, stats to report        │
└─────────────────────────────────────────────────────────┘
```

## Work Completed (on `diversity` branch)

### Phase 1: Samplesheet Schema ✅ COMPLETED
- **Commit**: 2ce8340
- **Changes**:
  - Added `pipeline_name` to `assets/schema_input.json` (required field)
  - Updated all test input CSVs with `pipeline_name` column
  - Updated README samplesheet examples

### Phase 2: Data Bridge Module ✅ COMPLETED
- **Commit**: 70660e3
- **Module**: `modules/local/csv_to_diversity_format/`
- **Files**:
  - `main.nf`: Process definition
  - `meta.yml`: Module metadata
  - `environment.yml`: R dependencies
  - `csv_to_diversity_format.R`: Converts wide 0/1/2 matrix to long-format CSVs
  - `tests/`: Test data files

### Phase 3: Diversity Modules (m01-m07) ✅ COMPLETED
- **Commits**: 5cf44ae, cc32123
- **Modules created**:
  1. `modules/local/diversity_prepare_data/` - m01
  2. `modules/local/diversity_null_hill/` - m02
  3. `modules/local/diversity_filtered_hill/` - m03
  4. `modules/local/diversity_pipeline_diff/` - m04
  5. `modules/local/diversity_filtered_vs_null/` - m05
  6. `modules/local/diversity_variance/` - m06
  7. `modules/local/diversity_plots/` - m07

### Phase 4: Pipeline Integration ✅ COMPLETED
- **Commit**: 06d1c10
- **Changes**:
  - Created `workflows/diversity_analysis.nf`: Chains all diversity modules
  - Updated `main.nf`: Includes DIVERSITY_ANALYSIS workflow
  - Updated `nextflow_schema.json`: Added `run_diversity` (boolean) and `demo_info` (file) params
  - Updated `README.md`: Added diversity analysis description
  - Added test files: `tests/diversity/`

### Phase 5: Tests ✅ PARTIAL
- Created stub test for diversity workflow
- Added test data: `input_diversity.csv`, `demo_info.csv`

## Current Branch Structure

```
diversity (06d1c10) ← HEAD (pushed to origin)
├── 2ce8340 feat(samplesheet): add pipeline_name column
├── 70660e3 feat: add data bridge and m01_prepare_data
├── 5cf44ae feat: add m03_filtered_hill module
├── cc32123 feat: add m04-m07 diversity modules
└── 06d1c10 feat: integrate diversity analysis pipeline
```

## Module Details

### Each Module Structure
```
modules/local/<module_name>/
├── main.nf          # Nextflow process definition
├── meta.yml         # Module metadata (nf-core standard)
├── environment.yml  # Conda environment with R packages
├── mXX_*.R          # R wrapper script calling Files2Tuebingen functions
└── tests/           # Test files (when applicable)
```

### R Dependencies by Module
- **m01-m03**: variantannotation, docopt, dplyr, readr, data.table, hillR, future, future.apply, purrr, progressr
- **m04-m06**: All above + vegan
- **m07**: All above + ggplot2, gridextra, pals

## Future Work

### 1. Run Local Tests ⏳
```bash
# Install nextflow if needed
curl -s "https://get.nextflow.io" | bash

# Run nf-core lint
nf-core lint --dir .

# Run nf-test (stub tests)
nf-test --profile test

# Run diversity stub test
nf-test tests/diversity/diversity.nf.test
```

### 2. Fix R Source Path Resolution 📝
The R wrapper scripts use `try_resolve_path()` to find Files2Tuebingen/R/. This works in the module directory but may need adjustment when the pipeline is run from different locations.

### 3. Add Full Snapshot Tests ⏳
Currently have stub tests. Need to create:
- Full data pipeline test with real VCF files
- Verify all module outputs exist and have correct format
- Compare against expected output files

### 4. Update MultiQC Integration ⏳
Extend MultiQC to include diversity analysis results:
- Summary YAML with diversity parameters
- CSV files from ANOVA tests as custom content
- Plots as custom figures
- Software versions for R packages

### 5. Add More Pipeline Parameters ⏳
Current schema has `run_diversity` and `demo_info`. Consider adding:
- `numCores` (integer, default: 1) - for parallel processing
- `numVariantSets` (integer, default: 100) - for Monte Carlo replicates
- `nPermutations` (integer, default: 9999) - for permutation tests
- `evaluatePopulation` (boolean, default: false) - population-level analysis
- `evaluateSuperPopulation` (boolean, default: false) - superpopulation analysis

### 6. Create Documentation ⏳
- Update `docs/usage.md` with diversity analysis examples
- Add pipeline diagram showing diversity stage
- Create user guide for diversity analysis parameters

### 7. Merge to dev ⏳
```bash
git checkout dev
git merge diversity --no-edit
git push origin dev
```

### 8. Cleanup ⏳
```bash
git branch -d diversity-integration  # Old branch
```

## How to Use

### Basic Run (VCF to counts only)
```bash
nextflow run qbic-pipelines/vcftocounts \
   -profile <docker/singularity/...> \
   --input samplesheet.csv \
   --genome GATK.GRCh38 \
   --outdir <OUTDIR>
```

### With Diversity Analysis
```bash
nextflow run qbic-pipelines/vcftocounts \
   -profile <docker/singularity/...> \
   --input samplesheet.csv \
   --genome GATK.GRCh38 \
   --run_diversity true \
   --demo_info demo_info.csv \
   --outdir <OUTDIR>
```

### Samplesheet Format
```csv
sample,pipeline_name,label,gvcf,vcf_path,vcf_index_path
SAMPLE-1,freebayes,chr22-freebayes,false,/path/to/vcf.gz,/path/to/vcf.gz.tbi
SAMPLE-1,strelka,chr22-strelka,false,/path/to/vcf.gz,/path/to/vcf.gz.tbi
SAMPLE-2,freebayes,chr22-freebayes,false,/path/to/vcf.gz,/path/to/vcf.gz.tbi
SAMPLE-2,strelka,chr22-strelka,false,/path/to/vcf.gz,/path/to/vcf.gz.tbi
```

### Demo Info Format
```csv
sample_name,population_code,super_population_code
SAMPLE-1,CHB,East_Asian
SAMPLE-2,JPT,East_Asian
```

## Summary

**Completed**: All 8 diversity modules created, integrated into pipeline, schema updated, README updated, tests stub created, pushed to origin.

**Remaining**: Run local tests, fix any issues, add full snapshot tests, update MultiQC, merge to dev.

**Next immediate step**: Run `nf-core lint` and `nf-test` to verify the pipeline runs correctly.
