#!/usr/bin/env Rscript
# m03_filtered_hill.R
# Module 03 - Calculate Hill numbers for filtered data
# Wraps the reference R analysis from Files2Tuebingen/R/hill_calculations.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 03 - filtered Hill numbers

Usage:
  m03_filtered_hill.R --in=<rdata> --out=<o> [--nullHill=<n>] [--qHillNumber=<q>]
  m03_filtered_hill.R -h|--help

Options:
  --in=<rdata>       Input prepared.RData checkpoint from m01
  --out=<o>          Output FilteredHillValues .RData file
  --nullHill=<n>     Optional NullHillValues .RData file
  --qHillNumber=<q>  Hill order [default: 2]
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "hill_calculations.R"))) {
  stop("Cannot find hill_calculations.R in src/ directory: ", source_dir)
}

message("=== Module 03: filtered_hill ===")

# Source reference functions
source(file.path(source_dir, "hill_calculations.R"))
source(file.path(source_dir, "utils.R"))

# Load prepared data
e <- new.env()
load(opt[["--in"]], envir = e)
res <- e$res

# Load null hill values if provided
NullHillValues <- NULL
if (!is.null(opt[["--nullHill"]])) {
  e2 <- new.env()
  load(opt[["--nullHill"]], envir = e2)
  NullHillValues <- e2$NullHillValues
  message("Loaded NullHillValues from: ", opt[["--nullHill"]])
}

qHillNumber <- as.numeric(opt[["--qHillNumber"]])
if (is.na(qHillNumber)) qHillNumber <- 2

message("Calculating filtered Hill numbers...")

FilteredHillValues <- calculate_filtered_hill(
  filtered_data = res$filtered_data,
  qHillNumber = qHillNumber,
  evaluatePopulation = FALSE,
  evaluateSuperPopulation = FALSE,
  downSampleByPop = FALSE,
  downSampleBySuperPop = FALSE,
  chunk_sample_sets = NULL,
  numVariantSets = 1,
  seed = 1234,
  variant_sample_fraction = 0.8
)

# Add metadata flags
FilteredHillValues$has_replicates <- FALSE
FilteredHillValues$num_replicates <- 1

# Save checkpoint
save(FilteredHillValues, file = opt[["--out"]])
message(sprintf("FilteredHillValues written to %s", opt[["--out"]]))

message("=== Module 03 complete ===")
