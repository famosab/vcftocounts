# Plan: Diversity Analysis Integration into vcftocounts

## Overview

Integrate Files2Tuebingen's diversity analysis (Hill numbers, ANOVA, permutation tests, plots) into the vcftocounts nf-core pipeline as new modules, enabling comparison of VCF sets from different pipelines.

## Current State

**Files2Tuebingen contains:**
- `main.R` (497 lines) - orchestrator running full pipeline
- `data_io.R` (175 lines) - `load_and_preprocess_data()` function
- `hill_calculations.R` (1875 lines) - Hill number calculations (Monte Carlo)
- `variance_analysis.R` (2294 lines) - ANOVA/permutation tests
- `plotting.R` (1075 lines) - diagnostic plots
- `utils.R` (79 lines) - utilities

**vcftocounts currently:**
1. VCF/gVCF → tabix → GATK → filter → concat → reheader → merge → annotate
2. VCF2COUNTS module: `vcf2counts.R` produces 0/1/2 genotype matrix
3. MultiQC report

**What I've done (branch `diversity`):**
- Added `pipeline_name` to schema (commit 2ce8340)
- Started `modules/local/diversity_prepare_data/` with meta.yml and environment.yml only

## Integration Architecture

```
VCF/gVCF files (multiple pipelines via pipeline_name)
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  EXISTING (unchanged):                                   │
│  tabix → GATK → filter → concat → reheader → merge     │
│  → annotate → vcf2counts.R (genotype matrix 0/1/2)     │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  NEW MODULES:                                           │
│                                                         │
│  m01: prepare_data                                      │
│    Input: filtered_csv, null_csv (from vcf2counts output │
│           converted to long-format)                     │
│    Output: prepared.RData + prepared_summary.csv        │
│    R function: load_and_preprocess_data() from         │
│                Files2Tuebingen/R/data_io.R              │
│                                                         │
│  m02: null_hill                                         │
│    Input: prepared.RData, demo_info                     │
│    Output: nullhill.RData                               │
│    R function: calculateNullHill() from                 │
│                Files2Tuebingen/R/hill_calculations.R    │
│                                                         │
│  m03: filtered_hill                                     │
│    Input: prepared.RData, nullhill.RData                │
│    Output: filteredhill.RData                           │
│    R function: calculate_filtered_hill() from           │
│                Files2Tuebingen/R/hill_calculations.R    │
│                                                         │
│  m04: pipeline_differences                              │
│    Input: nullhill.RData                                │
│    Output: CSVs in anova/                               │
│    R function: analyze_pipeline_differences() from      │
│                Files2Tuebingen/R/variance_analysis.R    │
│                                                         │
│  m05: filtered_vs_null                                  │
│    Input: nullhill.RData, filteredhill.RData            │
│    Output: CSVs in patterns/                            │
│    R function: compare_pipeline_patterns() from         │
│                Files2Tuebingen/R/variance_analysis.R    │
│                                                         │
│  m06: variance_decomposition                            │
│    Input: nullhill.RData                                │
│    Output: variance.RData                               │
│    R function: analyze_variance_decomposition() from    │
│                Files2Tuebingen/R/variance_analysis.R    │
│                                                         │
│  m07: plots                                             │
│    Input: nullhill.RData, filteredhill.RData            │
│    Output: plots/*.pdf, plots/*.csv                     │
│    R function: generate_all_plots() from                │
│                Files2Tuebingen/R/plotting.R             │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  MULTIQC (extended):                                    │
│  Add diversity summaries, plots, stats                  │
└─────────────────────────────────────────────────────────┘
```

## Work Plan (Incremental, One Module at a Time)

### Phase 1: Samplesheet Schema ✅ DONE (commit 2ce8340)
- [x] Add `pipeline_name` to schema_input.json
- [x] Update test input CSVs

### Phase 2: Data Bridge Module (NEW)
Create a module that converts vcf2counts output (0/1/2 matrix) to Files2Tuebingen format (long CSVs):
- Module: `modules/local/csv_to_diversity_format/`
- R script: converts wide-format 0/1/2 matrix to long-format with columns: `variant_called, sample_name, pipeline, genotype`
- Produces `filtered_counts.csv` and `null_counts.csv`
- R packages: variantannotation, docopt, dplyr, readr, data.table

### Phase 3: Diversity Modules (m01-m07) (NEW)
Each module in `modules/local/diversity_<name>/`:
- `main.nf` - process definition
- `meta.yml` - module metadata
- `environment.yml` - R dependencies
- `mXX_script.R` - wrapper script calling reference functions

**Order: m01→m02→m03→m04→m05→m06→m07** (sequential dependencies)

**m01_prepare_data** (already started with meta.yml and environment.yml)
- Wraps `load_and_preprocess_data()` from `data_io.R`
- Simple, fast, validates data format
- First to commit and test

**m02_null_hill** (heavy Monte Carlo stage)
- Wraps `calculateNullHill()` from `hill_calculations.R`
- Needs: hillR, future, future.apply, purrr, progressr packages
- Longest runtime process

**m03_filtered_hill**
- Wraps `calculate_filtered_hill()` from `hill_calculations.R`

**m04-m06: variance/ANOVA modules**
- Wrap functions from `variance_analysis.R`
- permutation tests (9999 permutations by default)

**m07: plots**
- Wraps `generate_all_plots()` from `plotting.R`
- Produces PDF plots + CSV statistics

### Phase 4: Pipeline Integration (NEW)
- Add diversity modules to `workflows/vcftocounts.nf`
- Update `main.nf` to include diversity workflow
- Add new parameters to `nextflow_schema.json`:
  - `run_diversity` (boolean, default false)
  - `demo_info` (file path for population metadata)
  - `evaluatePopulation`, `evaluateSuperPopulation` (booleans)
  - `numCores`, `numVariantSets`, `numSampleSets` (integers)
  - `qHillNumber` (number)
  - `nPermutations` (integer)

### Phase 5: Tests (NEW)
- nf-test files for each module
- Test data generation scripts
- Run locally with nf-test

### Phase 6: Documentation (NEW)
- Update README.md with diversity section
- Update nextflow_schema.json help_text for all new params
- Update MultiQC integration

## Branch Strategy
- Start from `dev`
- Create branch: `diversity-integration` (for this work)
- Each phase could be separate branch, but will do incrementally on this one branch
- Push to origin when each phase complete

## Next Steps (Ordered)
1. ✅ Commit Phase 1 (already done: commit 2ce8340)
2. 🔲 Create data bridge module (csv_to_diversity_format)
3. 🔲 Complete m01_prepare_data module (add main.nf + R wrapper)
4. 🔲 Add m02-m07 modules
5. 🔲 Wire into pipeline workflow
6. 🔲 Add tests
7. 🔲 Run nf-core lint
8. 🔲 Push to origin

## Risks & Mitigations
- **R packages**: Use Wave containers or conda environments
- **Memory**: hill_calculations.R is heavy (1875 lines) - expose `--maxGB` param
- **Reference bug**: Files2Tuebingen has known bug in generate_hill_chunks (character cols in GForce sum) - block downsampling until patched
- **Schema compat**: pipeline_name is required - update all existing test files
