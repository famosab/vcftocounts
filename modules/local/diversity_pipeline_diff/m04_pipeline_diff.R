#!/usr/bin/env Rscript
# m04_pipeline_diff.R
# Module 04 - Analyze pipeline differences using permutation tests
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 04 - pipeline differences (permutation tests)

Usage:
  m04_pipeline_diff.R --nullHill=<rdata> --outdir=<d>
  m04_pipeline_diff.R -h|--help

Options:
  --nullHill=<rdata>   Input nullhill.RData from m02
  --outdir=<d>         Output directory for CSV results
  --nPermutations=<n>  Number of permutations [default: 9999]
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

message("=== Module 04: pipeline_diff ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))

# Load null hill values
e <- new.env()
load(opt[["--nullHill"]], envir = e)
NullHillValues <- e$NullHillValues

# Create output directory
dir.create(opt[["--outdir"]], recursive = TRUE, showWarnings = FALSE)

message(sprintf("Reading null hill data: %s", opt[["--nullHill"]]))

# Run pipeline difference analysis using PairwiseTotalData
if (!is.null(NullHillValues$PairwiseTotalData)) {
  message("Analyzing Total Data...")
  results <- analyze_pipeline_differences(
    pairwise_data_by_group = list(AllData = NullHillValues$PairwiseTotalData),
    save_to_file = file.path(opt[["--outdir"]], "pipeline_anova_total.csv"),
    n_permutations = 9999
  )
  message("Total analysis complete")
} else {
  message("No PairwiseTotalData available for analysis")
}

message("=== Module 04 complete ===")