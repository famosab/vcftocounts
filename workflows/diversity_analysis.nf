/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    qbic-pipelines/vcftocounts - Diversity Analysis Workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Integrates Files2Tuebingen diversity analysis into the vcftocounts pipeline
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CSV_TO_DIVERSITY_FORMAT       } from '../modules/local/csv_to_diversity_format'
include { DIVERSITY_PREPARE_DATA        } from '../modules/local/diversity_prepare_data'
include { DIVERSITY_NULL_HILL           } from '../modules/local/diversity_null_hill'
include { DIVERSITY_FILTERED_HILL       } from '../modules/local/diversity_filtered_hill'
include { DIVERSITY_PIPELINE_DIFF       } from '../modules/local/diversity_pipeline_diff'
include { DIVERSITY_FILTERED_VS_NULL    } from '../modules/local/diversity_filtered_vs_null'
include { DIVERSITY_VARIANCE            } from '../modules/local/diversity_variance'
include { DIVERSITY_PLOTS               } from '../modules/local/diversity_plots'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN DIVERSITY WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DIVERSITY_ANALYSIS {
    take:
    ch_matrix          // channel: tuple val(meta), path(matrix_csv) from VCF2COUNTS
    ch_samplesheet     // channel: original samplesheet file path
    ch_demo_info       // channel: optional demographic info CSV
    outdir

    main:
    ch_multiqc_files = channel.empty()

    //
    // Stage 1: Convert matrix CSV to long-format CSVs for diversity analysis
    // CSV_TO_DIVERSITY_FORMAT expects: tuple val(meta), path(matrix_csv), path(samplesheet)
    //
    // Map the matrix channel to create 3-tuples with the samplesheet path
    def ch_samplesheet_path = ch_samplesheet.collect().first()
    
    def ch_matrix_for_csv = ch_matrix.map { meta, matrix_csv ->
        [meta, matrix_csv, ch_samplesheet_path]
    }

    CSV_TO_DIVERSITY_FORMAT(
        ch_matrix_for_csv
    )

    //
    // Stage 2: Prepare data for diversity analysis
    // DIVERSITY_PREPARE_DATA expects: tuple val(meta), path(filtered_csv), path(null_csv) + path(demo_info)
    // CSV_TO_DIVERSITY_FORMAT.out.combined_csv is: tuple val(meta), path(filtered_csv), path(null_csv)
    //
    DIVERSITY_PREPARE_DATA(
        CSV_TO_DIVERSITY_FORMAT.out.combined_csv,
        ch_demo_info
    )

    //
    // Stage 3: Calculate null distribution (Monte Carlo)
    // DIVERSITY_NULL_HILL expects: tuple val(meta), path(prepared_rdata) + path(demo_info) + path(chunk_dir)
    //
    def ch_prepared = DIVERSITY_PREPARE_DATA.out.prepared_rdata.map { meta, rdata ->
        [meta, rdata]
    }

    DIVERSITY_NULL_HILL(
        ch_prepared,
        ch_demo_info,
        channel.value([])  // chunk_dir - will be created by R script
    )

    //
    // Stage 4: Calculate filtered Hill numbers
    // DIVERSITY_FILTERED_HILL expects: tuple val(meta), path(prepared_rdata) + path(nullhill_rdata)
    //
    DIVERSITY_FILTERED_HILL(
        ch_prepared,
        DIVERSITY_NULL_HILL.out.nullhill_rdata
    )

    //
    // Stage 5: Analyze pipeline differences
    // DIVERSITY_PIPELINE_DIFF expects: tuple val(meta), path(nullhill_rdata)
    //
    def ch_nullhill = DIVERSITY_NULL_HILL.out.nullhill_rdata.map { meta, rdata ->
        [meta, rdata]
    }

    DIVERSITY_PIPELINE_DIFF(
        ch_nullhill
    )

    //
    // Stage 6: Compare filtered vs null patterns
    // DIVERSITY_FILTERED_VS_NULL expects: tuple val(meta), path(nullhill_rdata) + path(filteredhill_rdata)
    //
    DIVERSITY_FILTERED_VS_NULL(
        ch_nullhill,
        DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    )

    //
    // Stage 7: Variance decomposition
    // DIVERSITY_VARIANCE expects: tuple val(meta), path(nullhill_rdata)
    //
    DIVERSITY_VARIANCE(
        ch_nullhill
    )

    //
    // Stage 8: Generate plots
    // DIVERSITY_PLOTS expects: tuple val(meta), path(nullhill_rdata) + path(filteredhill_rdata)
    //
    DIVERSITY_PLOTS(
        ch_nullhill,
        DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    )

    emit:
    prepared_summary    = DIVERSITY_PREPARE_DATA.out.prepared_summary_csv
    nullhill_rdata      = DIVERSITY_NULL_HILL.out.nullhill_rdata
    filteredhill_rdata  = DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    anova_csv           = DIVERSITY_PIPELINE_DIFF.out.anova_csv
    pattern_csv         = DIVERSITY_FILTERED_VS_NULL.out.pattern_csv
    variance_rdata      = DIVERSITY_VARIANCE.out.variance_rdata
    plots               = DIVERSITY_PLOTS.out.plots
    versions_diversity  = DIVERSITY_PREPARE_DATA.out.versions_diversity_prepare_data
        .mix(DIVERSITY_NULL_HILL.out.versions_diversity_null_hill)
        .mix(DIVERSITY_FILTERED_HILL.out.versions_diversity_filtered_hill)
        .mix(DIVERSITY_PIPELINE_DIFF.out.versions_diversity_pipeline_diff)
        .mix(DIVERSITY_FILTERED_VS_NULL.out.versions_diversity_filtered_vs_null)
        .mix(DIVERSITY_VARIANCE.out.versions_diversity_variance)
        .mix(DIVERSITY_PLOTS.out.versions_diversity_plots)
}
