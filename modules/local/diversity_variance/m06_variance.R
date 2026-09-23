#!/usr/bin/env Rscript
# m06_variance.R
# Module 06 - Variance decomposition analysis
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 06 - variance decomposition

Usage:
  m06_variance.R --nullHill=<rdata> --out=<o>
  m06_variance.R -h|--help

Options:
  --nullHill=<rdata>   Input nullhill.RData from m02
  --out=<o>            Output variance.RData file
  --numSampleSets=<ns> Number of sample sets [default: 1]
  --numVariantSets=<nv> Number of variant sets [default: 100]
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

message("=== Module 06: variance ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))

# Load null hill values
e <- new.env()
load(opt[["--nullHill"]], envir = e)
NullHillValues <- e$NullHillValues

message(sprintf("Reading null hill data: %s", opt[["--nullHill"]]))

# Run variance decomposition
numSampleSets <- as.numeric(opt[["--numSampleSets"]])
numVariantSets <- as.numeric(opt[["--numVariantSets"]])

vd <- analyze_variance_decomposition(
  NullHillValues,
  numSampleSets,
  numVariantSets,
  metric_column = "TD_beta"
)

# Save results
save(vd, file = opt[["--out"]])
message(sprintf("Variance decomposition written to %s", opt[["--out"]]))

message("=== Module 06 complete ===")