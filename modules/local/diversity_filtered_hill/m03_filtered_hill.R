#!/usr/bin/env Rscript
# m03_filtered_hill.R
# Module 03 - Calculate Hill numbers for the filtered (observed) data
# Wraps the reference R analysis from Files2Tuebingen/R/hill_calculations.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 03 - filtered Hill numbers

Usage:
  m03_filtered_hill.R --in=<rdata> --out=<o> --nullHill=<n>
  m03_filtered_hill.R -h|--help

Options:
  --in=<rdata>       Input prepared.RData checkpoint from m01
  --out=<o>          Output FilteredHillValues .RData file
  --nullHill=<n>     Input nullhill.RData from m02
'

opt <- docopt::docopt(doc)

# Resolve Files2Tuebingen/R path
try_resolve_path <- function(p, depth = 5) {
  if (file.exists(p)) return(p)
  d <- dirname(normalizePath(p))
  for (i in 1:depth) d <- dirname(d)
  candidate <- file.path(d, "Files2Tuebingen", "R")
  if (file.exists(file.path(candidate, "hill_calculations.R"))) return(candidate)
  stop("Cannot resolve Files2Tuebingen/R from ", p)
}
source_dir <- try_resolve_path(
  ifelse(nchar(commandArgs(trailingOnly=FALSE)[1]) > 0,
         commandArgs(trailingOnly=FALSE)[1],
         normalizePath(sys.frame(1)$ofile))
)

message("=== Module 03: filtered_hill ===")

# Source reference functions
source(file.path(source_dir, "hill_calculations.R"))

# Load prepared data
e1 <- new.env()
load(opt[["--in"]], envir = e1)
res <- e1$res

# Load null hill values (needed for some comparisons)
e2 <- new.env()
load(opt[["--nullHill"]], envir = e2)
NullHillValues <- e2$NullHillValues

message(sprintf("Reading prepared data: %s", opt[["--in"]]))
message(sprintf("Reading null hill data: %s", opt[["--nullHill"]]))

# Run filtered hill calculation
FilteredHillValues <- calculate_filtered_hill(
  filtered_data = res$filtered_data,
  qHillNumber = 2,
  evaluatePopulation = FALSE,
  evaluateSuperPopulation = FALSE,
  downSampleByPop = FALSE,
  downSampleBySuperPop = FALSE,
  chunk_sample_sets = NULL,
  numVariantSets = 100,
  seed = 1234,
  variant_sample_fraction = 0.8
)

# Save checkpoint
save(FilteredHillValues, file = opt[["--out"]])
message(sprintf("FilteredHillValues written to %s", opt[["--out"]]))

message("=== Module 03 complete ===")