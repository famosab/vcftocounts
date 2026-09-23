#!/usr/bin/env Rscript
# m06_variance.R
# Module 06 - Variance decomposition analysis
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(dplyr))

doc <- '
Module 06 - variance decomposition

Usage:
  m06_variance.R --nullHill=<n> --out=<o>
  m06_variance.R -h|--help

Options:
  --nullHill=<n>     Input NullHillValues .RData file
  --out=<o>          Output variance.RData file
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "variance_analysis.R"))) {
  stop("Cannot find variance_analysis.R in src/ directory: ", source_dir)
}

message("=== Module 06: variance ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e <- new.env()
load(opt[["--nullHill"]], envir = e)
NullHillValues <- e$NullHillValues

message("Variance decomposition analysis (placeholder - no downsampling) ===")
message("Skipping variance decomposition (no downsampling performed)")

# For non-downsampled data, create empty/placeholder results
variance_decomposition <- list(
  total_variance = 0,
  between_sample_variance = 0,
  within_sample_variance = 0
)

# Save results
save(variance_decomposition, file = opt[["--out"]])
message(sprintf("Variance results saved to %s", opt[["--out"]]))

message("=== Module 06 complete ===")
