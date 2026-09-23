#!/usr/bin/env Rscript
# m04_pipeline_diff.R
# Module 04 - Analyze pipeline differences using ANOVA and Tukey HSD
# Wraps the reference R analysis from Files2Tuebingen/R/variance_analysis.R

suppressMessages(library(docopt))
suppressMessages(library(dplyr))

doc <- '
Module 04 - pipeline differences

Usage:
  m04_pipeline_diff.R --nullHill=<n> --outdir=<o>
  m04_pipeline_diff.R -h|--help

Options:
  --nullHill=<n>     Input NullHillValues .RData file
  --outdir=<o>       Output directory for results [default: anova]
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "variance_analysis.R"))) {
  stop("Cannot find variance_analysis.R in src/ directory: ", source_dir)
}

message("=== Module 04: pipeline_diff ===")

# Source reference functions
source(file.path(source_dir, "variance_analysis.R"))
source(file.path(source_dir, "utils.R"))

# Load null hill values
e <- new.env()
load(opt[["--nullHill"]], envir = e)
NullHillValues <- e$NullHillValues

# Create output directory
outdir <- opt[["--outdir"]]
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

message("Analyzing pipeline differences...")

pipeline_anova_results <- list()

anova_base_file <- file.path(outdir, "pipeline_anova")

# Analyze total data if available
if (!is.null(NullHillValues$PairwiseTotalData)) {
  message("Analyzing Total Data (All Samples)")
  total_data <- list(AllData = NullHillValues$PairwiseTotalData)
  anova_file <- paste0(anova_base_file, "_total.csv")
  
  pipeline_anova_results$total <- analyze_pipeline_differences(
    pairwise_data_by_group = total_data,
    save_to_file = anova_file,
    n_permutations = 9999
  )
} else {
  message("No PairwiseTotalData available - skipping total data analysis")
}

# Summary
if (length(pipeline_anova_results) == 0) {
  message("No Pipeline Differences Analysis Performed")
  pipeline_anova_results <- NULL
} else {
  message(sprintf("Pipeline Analysis Complete: %d level(s) analyzed", length(pipeline_anova_results)))
}

# Save results
save(pipeline_anova_results, file = file.path(outdir, "anova_results.RData"))
message(sprintf("Results saved to %s", file.path(outdir, "anova_results.RData")))

message("=== Module 04 complete ===")
