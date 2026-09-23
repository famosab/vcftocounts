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

# Resolve Files2Tuebingen/R path from this script's location
# Expected layout: modules/local/diversity_prepare_data/m01_prepare_data.R
#                  ../../../Files2Tuebingen/R/
try_resolve_path <- function(p, depth = 5) {
  if (file.exists(p)) return(p)
  d <- dirname(normalizePath(p))
  for (i in 1:depth) d <- dirname(d)
  candidate <- file.path(d, "Files2Tuebingen", "R")
  if (file.exists(file.path(candidate, "data_io.R"))) return(candidate)
  stop("Cannot resolve Files2Tuebingen/R from ", p)
}
source_dir <- try_resolve_path(
  ifelse(nchar(commandArgs(trailingOnly=FALSE)[1]) > 0,
         commandArgs(trailingOnly=FALSE)[1],
         normalizePath(sys.frame(1)$ofile))
)

message("=== Module 01: prepare_data ===")

# Source reference data_io functions
source(file.path(source_dir, "data_io.R"))

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