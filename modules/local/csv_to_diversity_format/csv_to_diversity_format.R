#!/usr/bin/env Rscript
# csv_to_diversity_format.R
# Convert vcf2counts wide-format (0/1/2 matrix) to Files2Tuebingen long-format CSVs
#
# vcf2counts output: rows=variants, cols=sample labels, values=0/1/2
# Files2Tuebingen expects: variant_called, sample_name, pipeline, genotype

suppressMessages(library(readr, warn.conflicts = FALSE, quietly = TRUE))
suppressMessages(library(dplyr, warn.conflicts = FALSE, quietly = TRUE))
suppressMessages(library(docopt, warn.conflicts = FALSE, quietly = TRUE))

doc <- '
Convert genotype matrix to diversity analysis format

Usage:
  csv_to_diversity_format.R --matrix=<m> --samplesheet=<s> \\
    --outFiltered=<oF> --outNull=<oN>
  csv_to_diversity_format.R -h|--help

Options:
  --matrix=<m>         Input genotype matrix CSV (0/1/2) from vcf2counts
  --samplesheet=<s>    Input samplesheet with sample, pipeline_name columns
  --outFiltered=<oF>   Output filtered CSV path
  --outNull=<oN>       Output null CSV path
'

opt <- docopt::docopt(doc)

message("=== Converting genotype matrix to diversity CSV format ===")
message(sprintf("Reading matrix: %s", opt[["--matrix"]]))

# Read the wide matrix
mat <- read.csv(opt[["--matrix"]], row.names = 1, check.names = FALSE)
message(sprintf("  Matrix dimensions: %d variants x %d samples", nrow(mat), ncol(mat)))

# Read samplesheet to get pipeline mappings
ss <- read.csv(opt[["--samplesheet"]], stringsAsFactors = FALSE)
message(sprintf("  Samplesheet rows: %d", nrow(ss)))

# Build label map: each col in matrix → (sample, pipeline)
# Columns are typically "label" from samplesheet (e.g., "chr22-freebayes")
label_map <- ss %>%
  select(label, sample, pipeline_name) %>%
  distinct()

# Transform wide to long
long_data <- list()

for (col in colnames(mat)) {
  # Find matching samplesheet row
  match <- label_map %>% filter(label == col)
  if (nrow(match) == 0) next
  
  sample_id <- match$sample[1]
  pipeline <- match$pipeline_name[1]
  
  # Get variants and genotypes for this sample
  variant_ids <- rownames(mat)
  genotypes <- mat[, col, drop = TRUE]
  
  for (i in seq_along(variant_ids)) {
    long_data[[length(long_data) + 1]] <- data.frame(
      variant_called = variant_ids[i],
      sample_name = sample_id,
      pipeline = pipeline,
      genotype = genotypes[i],
      stringsAsFactors = FALSE
    )
  }
}

# Combine into single long-format data frame
if (length(long_data) > 0) {
  long_df <- do.call(rbind, long_data)
  message(sprintf("  Long-format rows: %d", nrow(long_df)))
} else {
  stop("No data produced - check matrix/samplesheet format")
}

# Write both filtered and null CSVs (same format, difference is in which VCFs were included)
write.csv(long_df, opt[["outFiltered"]], row.names = FALSE)
write.csv(long_df, opt[["outNull"]], row.names = FALSE)

message(sprintf("  Filtered CSV: %s (%d rows)", opt[["outFiltered"]], nrow(long_df)))
message(sprintf("  Null CSV:     %s (%d rows)", opt[["outNull"]], nrow(long_df)))
message("=== Conversion complete ===")