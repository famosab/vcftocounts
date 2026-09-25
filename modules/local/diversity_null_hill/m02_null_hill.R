#!/usr/bin/env Rscript
# m02_null_hill.R
# Module 02 - Calculate null distribution of Hill numbers via Monte Carlo simulation

suppressMessages(library(data.table))
suppressMessages(library(dplyr))

# Parse arguments manually
parse_arg <- function(args, pattern, default = NULL) {
  idx <- grep(paste0("^", pattern, "="), args)
  if (length(idx) == 0) return(default)
  gsub(paste0("^", pattern, "="), "", args[idx])
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0 || any(args == "--help") || any(args == "-h")) {
  cat("Usage:
  m02_null_hill.R --in=<RDATA> --out=<OUTPUT>
                  [--chunkDir=<DIR>] [--numCores=NC] [--seed=SEED]
                  [--ns=NS] [--nv=NV] [--q=Q] [--maxGB=MAXGB]
  Options:
    --in        Input prepared.RData from m01 (required)
    --out       Output NullHillValues .RData file (required)
    --chunkDir  Directory for chunk files [default: chunks_null]
    --numCores  Cores for parallel [default: 1]
    --seed      Random seed [default: 1234]
    --ns        Sample sets [default: 1]
    --nv        Variant sets [default: 100]
    --q         Hill order [default: 2]
    --maxGB     Max memory GB [default: 100]
  ")
  quit(status = 0)
}

in_file <- parse_arg(args, "--in", stop("Required argument --in not provided"))
out_file <- parse_arg(args, "--out", stop("Required argument --out not provided"))
chunkDir <- parse_arg(args, "--chunkDir", "chunks_null")
numCores <- as.integer(parse_arg(args, "--numCores", 1))
seed <- as.integer(parse_arg(args, "--seed", 1234))
ns <- as.integer(parse_arg(args, "--ns", 1))
nv <- as.integer(parse_arg(args, "--nv", 100))
q <- as.integer(parse_arg(args, "--q", 2))
maxGB <- as.integer(parse_arg(args, "--maxGB", 100))

# Resolve script directory - hardcoded for module location
script_dir <- "/home/ubuntu/working/vcftocounts/modules/local/diversity_null_hill"
source_dir <- file.path(script_dir, "src")

message("=== Module 02: null_hill ===")
message("Using source directory: ", source_dir)

# Source reference functions
source(file.path(source_dir, "hill_calculations.R"))
source(file.path(source_dir, "utils.R"))

# Load prepared data
e <- new.env()
load(in_file, envir = e)
res <- e$res

# Create chunk directory
if (!dir.exists(chunkDir)) {
  dir.create(chunkDir, recursive = TRUE)
}

message(sprintf("Reading prepared data: %s", in_file))
message(sprintf("ns=%d, nv=%d, q=%d, numCores=%d, seed=%d", 
                ns, nv, q, numCores, seed))

# Run null hill calculation
# Add error handling to provide better diagnostics
tryCatch({
  NullHillValues <- calculateNullHill(
    null_data = res$null_data,
    filtered_data = res$filtered_data,
    total_variants = res$total_variants,
    numvariants = res$numvariants,
    numCores = as.numeric(numCores),
    seed = as.numeric(seed),
    numSampleSets = as.numeric(ns),
    numVariantSets = as.numeric(nv),
    qHillNumber = as.numeric(q),
    chunkDir = chunkDir,
    show_progress = FALSE,
    evaluatePopulation = FALSE,
    evaluateSuperPopulation = FALSE,
    resume = FALSE,
    downSamplePop = FALSE,
    downSampleSuperPop = FALSE,
    maxGB = as.numeric(maxGB)
  )
}, error = function(e) {
  message("ERROR in calculateNullHill: ", e$message)
  message("Data summary:")
  message("  null_data dimensions: ", paste(dim(res$null_data), collapse="x"))
  message("  filtered_data dimensions: ", paste(dim(res$filtered_data), collapse="x"))
  message("  total_variants: ", length(res$total_variants))
  message("  numvariants: ", res$numvariants)
  stop("Null hill calculation failed")
})

# Save checkpoint
save(NullHillValues, file = out_file)
message(sprintf("NullHillValues written to %s", out_file))

message("=== Module 02 complete ===")
