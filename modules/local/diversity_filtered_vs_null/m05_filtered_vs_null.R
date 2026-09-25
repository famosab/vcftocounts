#!/usr/bin/env Rscript
# m05_filtered_vs_null.R
# Module 05 - Compare filtered vs null pipeline patterns

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
  m05_filtered_vs_null.R --nullHill=<NULL> --filteredHill=<FILT> --outdir=<DIR>
  Options:
    --nullHill     Input NullHillValues .RData file (required)
    --filteredHill Input FilteredHillValues .RData file (required)
    --outdir       Output directory [default: patterns]
  ")
  quit(status = 0)
}

nullHill <- parse_arg(args, "--nullHill", stop("Required argument --nullHill not provided"))
filteredHill <- parse_arg(args, "--filteredHill", stop("Required argument --filteredHill not provided"))
outdir <- parse_arg(args, "--outdir", "patterns")

# Resolve script directory
script_dir <- "/home/ubuntu/working/vcftocounts/modules/local/diversity_filtered_vs_null"
source_dir <- file.path(script_dir, "src")

message("=== Module 05: filtered_vs_null ===")
message("Using source directory: ", source_dir)

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e1 <- new.env()
load(nullHill, envir = e1)
NullHillValues <- e1$NullHillValues

# Load filtered hill values
e2 <- new.env()
load(filteredHill, envir = e2)
FilteredHillValues <- e2$FilteredHillValues

# Create output directory
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

message("Comparing Filtered vs Null Pipeline Patterns...")

filtered_vs_null_results <- list()

# Compare total data if both exist
if (!is.null(FilteredHillValues$PairwiseTotalData) && !is.null(NullHillValues$PairwiseTotalData)) {
  message("Comparing Total Data Patterns")
  filt_total <- list(AllData = FilteredHillValues$PairwiseTotalData)
  null_total <- list(AllData = NullHillValues$PairwiseTotalData)
  comparison_file <- file.path(outdir, "comparison_results.csv")
  
  filtered_vs_null_results$total_pattern <- compare_pipeline_patterns(
    filtered_pairwise = filt_total,
    null_pairwise = null_total,
    save_to_file = comparison_file,
    n_permutations = 9999
  )
}

# Save results
save(filtered_vs_null_results, file = file.path(outdir, "pattern_results.RData"))
message(sprintf("Results saved to %s", file.path(outdir, "pattern_results.RData")))

message("=== Module 05 complete ===")
