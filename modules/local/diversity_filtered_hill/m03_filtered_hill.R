#!/usr/bin/env Rscript
# m03_filtered_hill.R
# Module 03 - Calculate Hill numbers for filtered data

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
  m03_filtered_hill.R --in=<RDATA> --out=<OUTPUT>
                      [--nullHill=<NULL>] [--q=Q]
  Options:
    --in        Input prepared.RData from m01 (required)
    --out       Output FilteredHillValues .RData file (required)
    --nullHill  Optional NullHillValues .RData file
    --q         Hill order [default: 2]
  ")
  quit(status = 0)
}

in_file <- parse_arg(args, "--in", stop("Required argument --in not provided"))
out_file <- parse_arg(args, "--out", stop("Required argument --out not provided"))
nullHill <- parse_arg(args, "--nullHill", NULL)
q <- as.integer(parse_arg(args, "--q", 2))

# Resolve script directory
script_dir <- "/home/ubuntu/working/vcftocounts/modules/local/diversity_filtered_hill"
source_dir <- file.path(script_dir, "src")

message("=== Module 03: filtered_hill ===")
message("Using source directory: ", source_dir)

# Source reference functions
source(file.path(source_dir, "hill_calculations.R"))
source(file.path(source_dir, "utils.R"))

# Load prepared data
e <- new.env()
load(in_file, envir = e)
res <- e$res

# Load null hill values if provided
NullHillValues <- NULL
if (!is.null(nullHill)) {
  e2 <- new.env()
  load(nullHill, envir = e2)
  NullHillValues <- e2$NullHillValues
  message("Loaded NullHillValues from: ", nullHill)
}

message("Calculating filtered Hill numbers...")

# Run filtered hill calculation
tryCatch({
  FilteredHillValues <- calculate_filtered_hill(
    filtered_data = res$filtered_data,
    qHillNumber = q,
    evaluatePopulation = FALSE,
    evaluateSuperPopulation = FALSE,
    downSampleByPop = FALSE,
    downSampleBySuperPop = FALSE,
    chunk_sample_sets = NULL,
    numVariantSets = 1,
    seed = 1234,
    variant_sample_fraction = 0.8
  )
}, error = function(e) {
  message("ERROR in calculate_filtered_hill: ", e$message)
  stop("Filtered hill calculation failed")
})

# Save checkpoint
save(FilteredHillValues, file = out_file)
message(sprintf("FilteredHillValues written to %s", out_file))

message("=== Module 03 complete ===")
