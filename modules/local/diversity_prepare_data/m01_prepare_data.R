#!/usr/bin/env Rscript
# m01_prepare_data.R
# Module 01 - prepare diversity data for Nextflow pipeline execution.
# Wraps the reference R analysis from Files2Tuebingen/R/data_io.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 01 - prepare diversity data

Usage:
  m01_prepare_data.R --filteredCSV=<f> --nullCSV=<n> --outdata=<o> [--outSummary=<s>] [--demoInfo=<d>]
  m01_prepare_data.R -h|--help

Options:
  --filteredCSV=<f>   Filtered count CSV (long format: variant_called, sample_name, ...)
  --nullCSV=<n>       Null/unfiltered count CSV (same format)
  --outdata=<o>       Output checkpoint .RData file
  --outSummary=<s>    Optional CSV summary [default: prepared_summary.csv]
  --demoInfo=<d>      Optional demographic info CSV (Run, population, Super_Population_Code, ...)
'

opt <- docopt::docopt(doc)

# Use local src directory (self-contained module)
script_dir <- dirname(normalizePath(sys.frame(1)$ofile))
source_dir <- file.path(script_dir, "src")

if (!file.exists(file.path(source_dir, "data_io.R"))) {
  stop("Cannot find data_io.R in src/ directory: ", source_dir)
}

message("=== Module 01: prepare_data ===")

# Source reference data_io functions
source(file.path(source_dir, "data_io.R"))
source(file.path(source_dir, "utils.R"))

message(sprintf("Reading filtered CSV: %s", opt[["--filteredCSV"]]))
message(sprintf("Reading null CSV: %s", opt[["--nullCSV"]]))

# Optional demo info
demoInfo <- if (!is.null(opt[["--demoInfo"]])) opt[["--demoInfo"]] else NULL

res <- load_and_preprocess_data(
    filteredCSV = opt[["--filteredCSV"]],
    nullCSV = opt[["--nullCSV"]],
    demoInfo = demoInfo
)

# Save checkpoint
save(res, file = opt[["--outdata"]])
message(sprintf("Checkpoint written to %s", opt[["--outdata"]]))

# Write a small summary CSV
summ <- data.frame(
    item = c("filtered_samples", "filtered_variants", "null_samples", "null_variants",
             "numvariants", "total_variants", "n_populations", "n_superpopulations"),
    value = c(
        length(unique(res$filtered_data$sample_name)),
        length(unique(res$filtered_data$variant_called)),
        length(unique(res$null_data$sample_name)),
        length(unique(res$null_data$variant_called)),
        res$numvariants,
        length(res$total_variants),
        if(!is.null(res$demoRunandEthnicity)) length(unique(res$demoRunandEthnicity$population_code)) else 0,
        if(!is.null(res$demoRunandEthnicity)) length(unique(res$demoRunandEthnicity$super_population_code)) else 0
    )
)
write.csv(summ, opt[["--outSummary"]], row.names = FALSE)
message(sprintf("Summary written to %s", opt[["--outSummary"]]))

message("=== Module 01 complete ===")
