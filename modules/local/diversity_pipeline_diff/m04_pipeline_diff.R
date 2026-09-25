#!/usr/bin/env Rscript
# m04_pipeline_diff.R
# Module 04 - Analyze pipeline differences using ANOVA and permutation tests

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
  m04_pipeline_diff.R --nullHill=<NULL> --outdir=<DIR>
  Options:
    --nullHill  Input NullHillValues .RData file (required)
    --outdir    Output directory [default: anova]
  ")
  quit(status = 0)
}

nullHill <- parse_arg(args, "--nullHill", stop("Required argument --nullHill not provided"))
outdir <- parse_arg(args, "--outdir", "anova")

# Resolve script directory
script_dir <- "/home/ubuntu/working/vcftocounts/modules/local/diversity_pipeline_diff"
source_dir <- file.path(script_dir, "src")

message("=== Module 04: pipeline_diff ===")
message("Using source directory: ", source_dir)

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e <- new.env()
load(nullHill, envir = e)
NullHillValues <- e$NullHillValues

# Create output directory
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

message("Analyzing pipeline differences...")

pipeline_anova_results <- list()

# Analyze total data if available
if (!is.null(NullHillValues$PairwiseTotalData)) {
  message("Analyzing Total Data")
  total_data <- list(AllData = NullHillValues$PairwiseTotalData)
  anova_file <- file.path(outdir, "anova_results.csv")
  
  pipeline_anova_results$total <- analyze_pipeline_differences(
    pairwise_data_by_group = total_data,
    save_to_file = anova_file,
    n_permutations = 9999
  )
} else {
  message("No PairwiseTotalData available")
}

# Save results
save(pipeline_anova_results, file = file.path(outdir, "anova_results.RData"))
message(sprintf("Results saved to %s", file.path(outdir, "anova_results.RData")))

message("=== Module 04 complete ===")
