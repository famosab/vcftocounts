#!/usr/bin/env Rscript
# m07_plots.R
# Module 07 - Generate diagnostic plots of diversity distributions
# Wraps the reference R analysis from Files2Tuebingen/R/plotting.R

suppressMessages(library(docopt))
suppressMessages(library(data.table))
suppressMessages(library(dplyr))

doc <- '
Module 07 - diagnostic plots

Usage:
  m07_plots.R --nullHill=<n> --filteredHill=<f> --outdir=<d>
  m07_plots.R -h|--help

Options:
  --nullHill=<n>       Input nullhill.RData from m02
  --filteredHill=<f>   Input filteredhill.RData from m03
  --outdir=<d>         Output directory for plots and CSVs
'

opt <- docopt::docopt(doc)

# Resolve Files2Tuebingen/R path
try_resolve_path <- function(p, depth = 5) {
  if (file.exists(p)) return(p)
  d <- dirname(normalizePath(p))
  for (i in 1:depth) d <- dirname(d)
  candidate <- file.path(d, "Files2Tuebingen", "R")
  if (file.exists(file.path(candidate, "plotting.R"))) return(candidate)
  stop("Cannot resolve Files2Tuebingen/R from ", p)
}
source_dir <- try_resolve_path(
  ifelse(nchar(commandArgs(trailingOnly=FALSE)[1]) > 0,
         commandArgs(trailingOnly=FALSE)[1],
         normalizePath(sys.frame(1)$ofile))
)

message("=== Module 07: plots ===")

# Source reference functions
source(file.path(source_dir, "plotting.R"))

# Load data
na <- new.env(); load(opt[["--nullHill"]], envir = na); NullHillValues <- na$NullHillValues
nb <- new.env(); load(opt[["--filteredHill"]], envir = nb); FilteredHillValues <- nb$FilteredHillValues

# Create output directory
dir.create(opt[["--outdir"]], recursive = TRUE, showWarnings = FALSE)

# Change to output directory for plotting (plots are generated relative to cwd)
old_wd <- getwd()
setwd(opt[["--outdir"]])

message("Generating plots...")

# Generate all plots
plot_results <- generate_all_plots(
  NullHillValues, FilteredHillValues,
  plotname = "diversity_plots.pdf",
  outputfile = "results.RData"
)

# Count outputs
n_pdf <- length(list.files(".", pattern = "\\.pdf$", recursive = TRUE))
n_csv <- length(list.files(".", pattern = "\\.csv$", recursive = TRUE))
message(sprintf("Generated %d PDF plots and %d CSV files", n_pdf, n_csv))

# Restore working directory
setwd(old_wd)

message("=== Module 07 complete ===")