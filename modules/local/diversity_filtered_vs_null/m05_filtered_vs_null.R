#!/usr/bin/env Rscript
# m05_filtered_vs_null.R
# Module 05 - Compare filtered vs null pipeline patterns
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(dplyr))

doc <- '
Module 05 - filtered vs null pattern comparison

Usage:
  m05_filtered_vs_null.R --nullHill=<n> --filteredHill=<f> --outdir=<o>
  m05_filtered_vs_null.R -h|--help

Options:
  --nullHill=<n>        Input NullHillValues .RData file
  --filteredHill=<f>    Input FilteredHillValues .RData file
  --outdir=<o>          Output directory for results [default: patterns]
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "variance_analysis.R"))) {
  stop("Cannot find variance_analysis.R in src/ directory: ", source_dir)
}

message("=== Module 05: filtered_vs_null ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e1 <- new.env()
load(opt[["--nullHill"]], envir = e1)
NullHillValues <- e1$NullHillValues

# Load filtered hill values
e2 <- new.env()
load(opt[["--filteredHill"]], envir = e2)
FilteredHillValues <- e2$FilteredHillValues

# Create output directory
outdir <- opt[["--outdir"]]
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

message("Comparing Filtered vs Null Pipeline Patterns...")

filtered_vs_null_results <- list()

comparison_base_file <- file.path(outdir, "filtered_vs_null")

# Compare total data if both exist
if (!is.null(FilteredHillValues$PairwiseTotalData) && !is.null(NullHillValues$PairwiseTotalData)) {
  message("Comparing Total Data Patterns")
  filt_total <- list(AllData = FilteredHillValues$PairwiseTotalData)
  null_total <- list(AllData = NullHillValues$PairwiseTotalData)
  comparison_file <- paste0(comparison_base_file, "_total.csv")
  
  filtered_vs_null_results$total_pattern <- compare_pipeline_patterns(
    filtered_pairwise = filt_total,
    null_pairwise = null_total,
    save_to_file = comparison_file,
    n_permutations = 9999
  )
}

# Summary
if (length(filtered_vs_null_results) > 0) {
  message(sprintf("Filtered vs Null Pattern Comparison Complete: %d level(s)", length(filtered_vs_null_results)))
} else {
  message("No comparison data available")
}

# Save results
save(filtered_vs_null_results, file = file.path(outdir, "pattern_results.RData"))
message(sprintf("Results saved to %s", file.path(outdir, "pattern_results.RData")))

message("=== Module 05 complete ===")
