#!/usr/bin/env Rscript
# m05_filtered_vs_null.R
# Module 05 - Compare filtered vs null pipeline patterns
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 05 - filtered vs null pattern comparison

Usage:
  m05_filtered_vs_null.R --nullHill=<n> --filteredHill=<f> --outdir=<d>
  m05_filtered_vs_null.R -h|--help

Options:
  --nullHill=<n>       Input nullhill.RData from m02
  --filteredHill=<f>   Input filteredhill.RData from m03
  --outdir=<d>         Output directory for CSV results
'

opt <- docopt::docopt(doc)

# Resolve Files2Tuebingen/R path
try_resolve_path <- function(p, depth = 5) {
  if (file.exists(p)) return(p)
  d <- dirname(normalizePath(p))
  for (i in 1:depth) d <- dirname(d)
  candidate <- file.path(d, "Files2Tuebingen", "R")
  if (file.exists(file.path(candidate, "variance_analysis.R"))) return(candidate)
  stop("Cannot resolve Files2Tuebingen/R from ", p)
}
source_dir <- try_resolve_path(
  ifelse(nchar(commandArgs(trailingOnly=FALSE)[1]) > 0,
         commandArgs(trailingOnly=FALSE)[1],
         normalizePath(sys.frame(1)$ofile))
)

message("=== Module 05: filtered_vs_null ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))

# Load data
na <- new.env(); load(opt[["--nullHill"]], envir = na); NullHillValues <- na$NullHillValues
nb <- new.env(); load(opt[["--filteredHill"]], envir = nb); FilteredHillValues <- nb$FilteredHillValues

# Create output directory
dir.create(opt[["--outdir"]], recursive = TRUE, showWarnings = FALSE)

message("Comparing filtered vs null patterns...")

# Compare total data if both exist
if (!is.null(FilteredHillValues$PairwiseTotalData) && !is.null(NullHillValues$PairwiseTotalData)) {
  message("Comparing Total Data patterns...")
  compare_pipeline_patterns(
    filtered_pairwise = list(AllData = FilteredHillValues$PairwiseTotalData),
    null_pairwise = list(AllData = NullHillValues$PairwiseTotalData),
    save_to_file = file.path(opt[["--outdir"]], "filtered_vs_null_total.csv"),
    n_permutations = 9999
  )
  message("Total pattern comparison complete")
} else {
  message("Cannot compare: missing PairwiseTotalData")
}

message("=== Module 05 complete ===")