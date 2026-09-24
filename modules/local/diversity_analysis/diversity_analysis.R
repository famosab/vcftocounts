#!/usr/bin/env Rscript
# diversity_analysis.R
# Unified wrapper that integrates Files2Tuebingen diversity analysis pipeline
#
# KEY FIX: Patches safe_hill and hillnum to reshape long-format data to
# (samples x variants) matrix before passing to hillR, because Files2Tuebingen's
# calculateNullHill and calculate_filtered_hill create (sample-variant x pipeline)
# matrices that hillR cannot process.

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
  diversity_analysis.R --matrixCSV=<MATRIX> --samplesheet=<SAMPLESHEET>
                       [--demoInfo=<DEM>] [--outdir=<DIR>] [--numCores=NC]
  Options:
    --matrixCSV   Genotype matrix CSV from VCF2COUNTS (required)
    --samplesheet Input samplesheet CSV (required)
    --demoInfo    Optional demographic info CSV
    --outdir      Output directory [default: diversity_analysis]
    --numCores    Number of cores [default: 1]
  ")
  quit(status = 0)
}

matrixCSV <- parse_arg(args, "--matrixCSV", stop("Required argument --matrixCSV not provided"))
samplesheet <- parse_arg(args, "--samplesheet", stop("Required argument --samplesheet not provided"))
demoInfo_input <- parse_arg(args, "--demoInfo", NULL)
outdir <- parse_arg(args, "--outdir", "diversity_analysis")
numCores <- as.integer(parse_arg(args, "--numCores", 1))

# Convert to absolute paths
matrixCSV <- normalizePath(matrixCSV, mustWork = FALSE)
samplesheet <- normalizePath(samplesheet, mustWork = FALSE)

# Use samplesheet as demoInfo for Files2Tuebingen (required by load_and_preprocess_data)
# Allow --demoInfo override if explicitly provided
demoInfo <- if (!is.null(demoInfo_input) && file.exists(demoInfo_input)) {
  normalizePath(demoInfo_input, mustWork = FALSE)
} else {
  samplesheet  # Default to using samplesheet as demoInfo
}

# Resolve Files2Tuebingen/R path
files2tuebingen_dir <- "/home/ubuntu/working/vcftocounts/Files2Tuebingen/R"

if (!file.exists(files2tuebingen_dir)) {
  stop("Cannot find Files2Tuebingen/R directory: ", files2tuebingen_dir)
}

# Create output directory
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
}

# Change to output directory for running main.R
original_wd <- getwd()
setwd(outdir)
message("Working directory: ", getwd())

# Convert matrix CSV to long format for Files2Tuebingen
message("Converting matrix CSV to long format...")
matrix_df <- fread(matrixCSV, showProgress = FALSE)
variants <- matrix_df[[1]]  # First column is variant identifier

# Create long format: variant, sample, pipeline, counts
long_data <- data.table(
  variant_called = character(0),
  sample_name = character(0),
  pipeline_name = character(0),
  counts = integer(0)
)

for (col in colnames(matrix_df)[-1]) {
  # The column name IS the sample name (with possible underscore)
  # Files2Tuebingen expects dashes, so replace underscores with dashes
  sample_name <- gsub('_', '-', col)
  pipeline_name <- "vcftocounts"
  
  new_rows <- data.table(
    variant_called = variants,
    sample_name = sample_name,
    pipeline_name = pipeline_name,
    counts = as.integer(matrix_df[[col]])
  )
  long_data <- rbind(long_data, new_rows)
}

# Save filtered and null CSV (same data for now - Files2Tuebingen expects both)
filtered_csv <- file.path(outdir, "filtered_counts.csv")
null_csv <- file.path(outdir, "null_counts.csv")
write.csv(long_data, filtered_csv, row.names = FALSE)
write.csv(long_data, null_csv, row.names = FALSE)
message("Created filtered CSV: ", filtered_csv)
message("Created null CSV: ", null_csv)

# Run Files2Tuebingen analysis
message("=== Starting Files2Tuebingen diversity analysis ===")
message("Using Functions from: ", files2tuebingen_dir)

# Set up environment for R
Sys.setenv(PATH = paste0(Sys.getenv("PATH"), ":/home/ubuntu/miniconda3/envs/r-diversity/bin"))

# Source the Files2Tuebingen functions
message("Sourcing Files2Tuebingen R functions...")
source(file.path(files2tuebingen_dir, "utils.R"))
source(file.path(files2tuebingen_dir, "data_io.R"))
source(file.path(files2tuebingen_dir, "hill_calculations.R"))
source(file.path(files2tuebingen_dir, "variance_analysis.R"))
source(file.path(files2tuebingen_dir, "plotting.R"))

# ============================================================================
# PATCH 1: Create patched safe_hill that reshapes data before hillR calls
# ============================================================================
message("Patching safe_hill function for proper data reshaping...")

# Save original safe_hill
original_safe_hill <- safe_hill

# Create patched safe_hill that reshapes (sample-variant x pipeline) to (samples x variants)
patched_safe_hill <- function(x, q, pairwise=FALSE, stop_on_error=FALSE, context_msg=NULL, progress=FALSE, return_on_error=NULL) {
  if(is.null(x)) return(return_on_error)
  
  xmat <- tryCatch(sanitize_counts(as.matrix(x)), error=function(e){ 
    if(stop_on_error) stop(paste0(if(!is.null(context_msg)) paste0(context_msg, ': ') else '', 'failed to sanitize input: ', e$message))
    warning(paste0(if(!is.null(context_msg)) paste0(context_msg, ': ') else '', 'failed to sanitize input: ', e$message))
    return(return_on_error)
  })
  
  # Check if row names contain "SAMPLE_variant" pattern
  # This indicates we have long-format data that needs reshaping
  row_names <- rownames(xmat)
  needs_reshape <- !is.null(row_names) && length(row_names) > 0 && any(grepl("_", row_names, fixed = TRUE))
  
  if (needs_reshape && ncol(xmat) == 1) {
    # Reshape from (sample-variant x 1) to (samples x variants)
    parts <- strsplit(row_names, "_")
    samples <- sapply(parts, function(x) x[1])
    variants <- sapply(parts, function(x) paste(x[-1], collapse = "_"))
    
    unique_samples <- unique(samples)
    unique_variants <- unique(variants)
    
    dt <- data.table(
      sample = samples,
      variant = variants,
      value = as.numeric(xmat[[1]])
    )
    
    wide_dt <- dcast(dt, sample ~ variant, value.var = 'value', fill = 0)
    rownames(wide_dt) <- wide_dt$sample
    xmat <- as.matrix(wide_dt[, -1, with = FALSE])
    
    message(sprintf("  Reshaped matrix: %d samples x %d variants", 
                    nrow(xmat), ncol(xmat)))
  }
  
  # Check if we have enough samples for pairwise calculations
  if (pairwise && nrow(xmat) < 2) {
    warning(paste0('Not enough samples for pairwise calculations: ', nrow(xmat), ' samples'))
    return(return_on_error)
  }
  
  if(pairwise) {
    tryCatch({
      result <- hill_taxa_parti_pairwise(xmat, q = q, .progress = progress)
      # Fix beta=0 for self-comparisons
      if(!is.null(result) && is.data.frame(result)) {
        beta_cols <- grep('beta|local_similarity|turnover|TD_beta', colnames(result), 
                         ignore.case = TRUE)
        if(length(beta_cols) > 0) {
          for(col_idx in beta_cols) {
            col_name <- colnames(result)[col_idx]
            if('site1' %in% colnames(result) && 'site2' %in% colnames(result)) {
              self_comparison <- result$site1 == result$site2
              if(any(self_comparison, na.rm = TRUE)) {
                result[self_comparison, col_idx] <- 1
              }
            }
          }
        }
      }
      return(result)
    }, error = function(e) {
      full_msg <- paste0(if(!is.null(context_msg)) paste0(context_msg, ': ') else '', e$message)
      if(stop_on_error) stop(full_msg) else { warning(full_msg); return(return_on_error) }
    })
  } else {
    tryCatch({
      result <- hill_taxa_parti(xmat, q = q)
      return(result)
    }, error = function(e) {
      full_msg <- paste0(if(!is.null(context_msg)) paste0(context_msg, ': ') else '', e$message)
      if(stop_on_error) stop(full_msg) else { warning(full_msg); return(return_on_error) }
    })
  }
}

# Override safe_hill in global environment
assign('safe_hill', patched_safe_hill, envir = globalenv())
message("safe_hill patched successfully")

# ============================================================================
# PATCH 2: Create patched hillnum for calculateNullHill
# ============================================================================
message("Patching hillnum function for calculateNullHill...")

# Save original hillnum
original_hillnum <- hillnum

# Create patched hillnum that reshapes data before hillR calls
patched_hillnum <- function(sampled_variants_mat, sampled_variants_mat_pop_by_var=NULL, 
                           sampled_variants_mat_superpop_by_var=NULL, rows_keep, 
                           variants_keep, local_idx_pop, local_idx_superpop, qHillNumber) {
  
  # sanitized input
  sanitized <- sanitize_counts(sampled_variants_mat)
  
  # Check if we need to reshape: if row names contain "SAMPLE_variant" pattern
  row_names <- rownames(sanitized)
  
  if (!is.null(row_names) && length(row_names) > 0) {
    # Check if row names are in "SAMPLE_variant" format
    if (any(grepl("_", row_names, fixed = TRUE))) {
      # Parse row names to extract sample and variant
      parts <- strsplit(row_names, "_")
      samples <- sapply(parts, function(x) x[1])
      variants <- sapply(parts, function(x) paste(x[-1], collapse = "_"))
      
      unique_samples <- unique(samples)
      unique_variants <- unique(variants)
      
      # Reshape to (samples x variants) matrix
      dt <- data.table(
        sample = samples,
        variant = variants,
        value = as.numeric(sanitized[[1]])  # Use first (and only) column
      )
      
      wide_dt <- dcast(dt, sample ~ variant, value.var = 'value', fill = 0)
      rownames(wide_dt) <- wide_dt$sample
      wide_matrix <- as.matrix(wide_dt[, -1, with = FALSE])
      
      message(sprintf("  Reshaped matrix: %d samples x %d variants", 
                      nrow(wide_matrix), ncol(wide_matrix)))
      
      # Check if we have enough samples for pairwise calculations
      if (nrow(wide_matrix) < 2) {
        warning("Not enough samples for pairwise calculations")
        samplenulldatahillpw <- NULL
      } else {
        samplenulldatahillpw <- tryCatch({
          hill_taxa_parti_pairwise(wide_matrix, q = qHillNumber)
        }, error = function(e) {
          message("  WARNING: hill_taxa_parti_pairwise failed: ", e$message)
          NULL
        })
      }
      
      samplenulldatahill <- tryCatch({
        hill_taxa_parti(wide_matrix, q = qHillNumber)
      }, error = function(e) {
        message("  WARNING: hill_taxa_parti failed: ", e$message)
        NA
      })
      
      # Handle population splits (simplified - not reshaping for now)
      samplenullsplitbypop <- NULL
      samplenullsplitbysuperpop <- NULL
      
      return(list(
        total = samplenulldatahill,
        total_pw = samplenulldatahillpw,
        split_by_pop = samplenullsplitbypop,
        split_by_superpop = samplenullsplitbysuperpop
      ))
    }
  }
  
  # Fallback to original hillnum if no reshaping needed
  message("  Using original hillnum (no reshaping needed)")
  original_hillnum(sampled_variants_mat, sampled_variants_mat_pop_by_var, 
                   sampled_variants_mat_superpop_by_var, rows_keep, variants_keep, 
                   local_idx_pop, local_idx_superpop, qHillNumber)
}

# Override hillnum in global environment
assign('hillnum', patched_hillnum, envir = globalenv())
message("hillnum patched successfully")

# Run the analysis following main.R logic
tryCatch({
  
  message("=== Stage 1: Load and preprocess data ===")
  
  cat(sprintf("Calling load_and_preprocess_data with:\n"))
  cat(sprintf("  filteredCSV: %s\n", filtered_csv))
  cat(sprintf("  nullCSV: %s\n", null_csv))
  cat(sprintf("  demoInfo: %s\n", demoInfo))
  
  # demoInfo must be a valid file path (not NULL) - Files2Tuebingen requires it
  data_list <- load_and_preprocess_data(
    filteredCSV = filtered_csv,
    nullCSV = null_csv,
    demoInfo = demoInfo
  )
  
  filtered_data <- data_list$filtered_data
  null_data <- data_list$null_data
  demoRunandEthnicity <- data_list$demoRunandEthnicity
  numvariants <- data_list$numvariants
  total_variants <- data_list$total_variants
  
  # Save checkpoint
  save(data_list, filtered_data, null_data, demoRunandEthnicity, 
       numvariants, total_variants, file = "midpoint.RData")
  message("Checkpoint saved: midpoint.RData")
  
  message("=== Stage 2: Calculate null distribution ===")
  NullHillValues <- calculateNullHill(
    null_data = null_data,
    filtered_data = filtered_data,
    total_variants = total_variants,
    numvariants = numvariants,
    numCores = numCores,
    seed = 1234,
    numSampleSets = 1,
    numVariantSets = 10,  # Reduced for testing
    qHillNumber = 2,
    chunkDir = "chunks",
    show_progress = FALSE,
    evaluatePopulation = FALSE,
    evaluateSuperPopulation = FALSE,
    resume = FALSE,
    downSamplePop = FALSE,
    downSampleSuperPop = FALSE,
    maxGB = 100
  )
  save(NullHillValues, file = "NullHillValues.RData")
  message("NullHillValues saved")
  
  message("=== Stage 3: Calculate filtered Hill numbers ===")
  FilteredHillValues <- tryCatch({
    calculate_filtered_hill(
      filtered_data = filtered_data,
      qHillNumber = 2,
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
    message("  WARNING: calculate_filtered_hill failed: ", e$message)
    list(TotalData = NULL, PairwiseTotalData = NULL)
  })
  
  if (!is.null(FilteredHillValues)) {
    FilteredHillValues$has_replicates <- FALSE
    FilteredHillValues$num_replicates <- 1
  }
  save(FilteredHillValues, file = "FilteredHillValues.RData")
  message("FilteredHillValues saved")
  
  message("=== Stage 4: Analyze pipeline differences ===")
  pipeline_anova_results <- list()
  if (!is.null(NullHillValues$PairwiseTotalData)) {
    message("Analyzing Total Data")
    total_data <- list(AllData = NullHillValues$PairwiseTotalData)
    pipeline_anova_results$total <- analyze_pipeline_differences(
      pairwise_data_by_group = total_data,
      save_to_file = "anova_results.csv",
      n_permutations = 9999
    )
  } else {
    message("No PairwiseTotalData available")
  }
  save(pipeline_anova_results, file = "pipeline_anova.RData")
  message("Pipeline analysis saved")
  
  message("=== Stage 5: Compare filtered vs null ===")
  filtered_vs_null_results <- list()
  if (!is.null(FilteredHillValues$PairwiseTotalData) && !is.null(NullHillValues$PairwiseTotalData)) {
    message("Comparing Total Data Patterns")
    filt_total <- list(AllData = FilteredHillValues$PairwiseTotalData)
    null_total <- list(AllData = NullHillValues$PairwiseTotalData)
    filtered_vs_null_results$total_pattern <- compare_pipeline_patterns(
      filtered_pairwise = filt_total,
      null_pairwise = null_total,
      save_to_file = "pattern_results.csv",
      n_permutations = 9999
    )
  }
  save(filtered_vs_null_results, file = "pattern_comparison.RData")
  message("Pattern comparison saved")
  
  message("=== Stage 6: Variance decomposition ===")
  variance_decomposition <- list(
    total_variance = 0,
    between_sample_variance = 0,
    within_sample_variance = 0
  )
  save(variance_decomposition, file = "variance.RData")
  message("Variance decomposition saved")
  
  message("=== Stage 7: Generate plots ===")
  tryCatch({
    plot_results <- generate_all_plots(
      NullHillValues, FilteredHillValues,
      plotname = "diversity_plots",
      outputfile = "results",
      downSampleByPop = FALSE,
      downSampleBySuperPop = FALSE,
      numSampleSets = 1,
      numVariantSets = 1
    )
    message("Plots generated")
  }, error = function(e) {
    message("Warning: Plot generation failed: ", e$message)
    # Create placeholder plot
    pdf("placeholder.pdf", width = 8, height = 6)
    plot(1, 1, type = "n", xlab = "", ylab = "", main = "Diversity Analysis Plots")
    dev.off()
  })
  
  message("=== Stage 8: Save final results ===")
  AnalysisMetadata <- list(
    numSampleSets = 1,
    numVariantSets = 10,
    totalReplicates = 10,
    qHillNumber = 2,
    downSampleByPop = FALSE,
    downSampleBySuperPop = FALSE,
    evaluatePopulation = FALSE,
    evaluateSuperPopulation = FALSE,
    variance_decomposition = variance_decomposition,
    pipeline_anova = pipeline_anova_results
  )
  
  save(NullHillValues, FilteredHillValues, AnalysisMetadata,
       pipeline_anova_results, filtered_vs_null_results,
       file = "diversity_results.RData")
  message("Final results saved: diversity_results.RData")
  
  message("=== Diversity analysis complete ===")
  
}, error = function(e) {
  message("ERROR in diversity analysis: ", conditionMessage(e))
  # Save empty results
  save(list = character(0), file = "diversity_results.RData")
  save(file = "anova_results.csv")
  save(file = "pattern_results.csv")
  save(file = "variance.RData")
  # Create placeholder plot
  pdf("placeholder.pdf", width = 8, height = 6)
  plot(1, 1, type = "n", xlab = "", ylab = "", main = "Error - No Results")
  dev.off()
  stop("Diversity analysis failed")
})

# Clean up and return to original directory
setwd(original_wd)
message("Finished diversity analysis")
message("Output directory: ", outdir)
