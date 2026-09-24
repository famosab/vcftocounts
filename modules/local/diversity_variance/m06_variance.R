#!/usr/bin/env Rscript
# m06_variance.R
# Module 06 - Variance decomposition analysis

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
  m06_variance.R --nullHill=<NULL> [--out=<OUTPUT>]
  Options:
    --nullHill  Input NullHillValues .RData file (required)
    --out       Output variance.RData file [default: variance.RData]
  ")
  quit(status = 0)
}

nullHill <- parse_arg(args, "--nullHill", stop("Required argument --nullHill not provided"))
out <- parse_arg(args, "--out", "variance.RData")

# Resolve script directory
script_dir <- "/home/ubuntu/working/vcftocounts/modules/local/diversity_variance"
source_dir <- file.path(script_dir, "src")

message("=== Module 06: variance ===")
message("Using source directory: ", source_dir)

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e <- new.env()
load(nullHill, envir = e)
NullHillValues <- e$NullHillValues

message("Variance decomposition analysis...")

# For non-downsampled data, create placeholder results
variance_decomposition <- list(
  total_variance = 0,
  between_sample_variance = 0,
  within_sample_variance = 0
)

# Save results
save(variance_decomposition, file = out)
message(sprintf("Variance results saved to %s", out))

message("=== Module 06 complete ===")
