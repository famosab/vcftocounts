#!/usr/bin/env Rscript
# m02_null_hill.R
# Module 02 - Calculate null distribution of Hill numbers via Monte Carlo simulation
# Wraps the reference R analysis from Files2Tuebingen/R/hill_calculations.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 02 - null distribution Hill numbers

Usage:
  m02_null_hill.R --in=<rdata> --out=<o> [--chunkDir=<c>] [--numCores=<nc>] [--seed=<seed>]
    [--numSampleSets=<ns>] [--numVariantSets=<nv>] [--qHillNumber=<q>] [--maxGB=<g>]
    [--demoInfo=<d>]
  m02_null_hill.R -h|--help

Options:
  --in=<rdata>           Input prepared.RData checkpoint from m01
  --out=<o>              Output NullHillValues .RData file
  --chunkDir=<c>         Directory for chunk files [default: chunks_null]
  --numCores=<nc>        Cores for future.apply [default: 1]
  --seed=<seed>          RNG seed [default: 1234]
  --numSampleSets=<ns>   Outer-loop replicates [default: 1]
  --numVariantSets=<nv>  Inner-loop replicates [default: 100]
  --qHillNumber=<q>      Hill order [default: 2]
  --maxGB=<g>            Max memory for future globals in GB [default: 100]
  --demoInfo=<d>         Optional demographic info CSV
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "hill_calculations.R"))) {
  stop("Cannot find hill_calculations.R in src/ directory: ", source_dir)
}

message("=== Module 02: null_hill ===")

# Source reference functions
source(file.path(source_dir, "hill_calculations.R"))
source(file.path(source_dir, "utils.R"))

# Load prepared data
e <- new.env()
load(opt[["--in"]], envir = e)
res <- e$res

# Create chunk directory
chunkDir <- if (!is.null(opt[["--chunkDir"]])) opt[["--chunkDir"]] else "chunks_null"
if (!file.exists(chunkDir)) {
  dir.create(chunkDir, recursive = TRUE)
}

message(sprintf("Reading prepared data: %s", opt[["--in"]]))

# Run null hill calculation
NullHillValues <- calculateNullHill(
  null_data = res$null_data,
  filtered_data = res$filtered_data,
  total_variants = res$total_variants,
  numvariants = res$numvariants,
  numCores = as.numeric(opt[["--numCores"]]),
  seed = as.numeric(opt[["--seed"]]),
  numSampleSets = as.numeric(opt[["--numSampleSets"]]),
  numVariantSets = as.numeric(opt[["--numVariantSets"]]),
  qHillNumber = as.numeric(opt[["--qHillNumber"]]),
  chunkDir = chunkDir,
  show_progress = FALSE,
  evaluatePopulation = FALSE,
  evaluateSuperPopulation = FALSE,
  resume = FALSE,
  downSamplePop = FALSE,
  downSampleSuperPop = FALSE,
  maxGB = as.numeric(opt[["--maxGB"]])
)

# Save checkpoint
save(NullHillValues, file = opt[["--out"]])
message(sprintf("NullHillValues written to %s", opt[["--out"]]))

message("=== Module 02 complete ===")
