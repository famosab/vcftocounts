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
    ch_matrix_csv          // channel: genotype matrix CSV from VCF2COUNTS
    ch_samplesheet         // channel: samplesheet CSV
    ch_demo_info           // optional: demographic info CSV
    outdir

    main:
    ch_multiqc_files = channel.empty()

    //
    // Stage 1: Convert matrix to long-format CSVs
    //
    CSV_TO_DIVERSITY_FORMAT(
        ch_matrix_csv,
        ch_samplesheet
    )

    //
    // Stage 2: Prepare data for diversity analysis
    //
    DIVERSITY_PREPARE_DATA(
        CSV_TO_DIVERSITY_FORMAT.out.filtered_csv,
        CSV_TO_DIVERSITY_FORMAT.out.null_csv,
        ch_demo_info
    )

    //
    // Stage 3: Calculate null distribution (Monte Carlo)
    //
    DIVERSITY_NULL_HILL(
        DIVERSITY_PREPARE_DATA.out.prepared_rdata,
        ch_demo_info
    )

    //
    // Stage 4: Calculate filtered Hill numbers
    //
    DIVERSITY_FILTERED_HILL(
        DIVERSITY_PREPARE_DATA.out.prepared_rdata,
        DIVERSITY_NULL_HILL.out.nullhill_rdata
    )

    //
    // Stage 5: Analyze pipeline differences
    //
    DIVERSITY_PIPELINE_DIFF(
        DIVERSITY_NULL_HILL.out.nullhill_rdata
    )

    //
    // Stage 6: Compare filtered vs null patterns
    //
    DIVERSITY_FILTERED_VS_NULL(
        DIVERSITY_NULL_HILL.out.nullhill_rdata,
        DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    )

    //
    // Stage 7: Variance decomposition
    //
    DIVERSITY_VARIANCE(
        DIVERSITY_NULL_HILL.out.nullhill_rdata
    )

    //
    // Stage 8: Generate plots
    //
    DIVERSITY_PLOTS(
        DIVERSITY_NULL_HILL.out.nullhill_rdata,
        DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    )

    emit:
    prepared_summary    = DIVERSITY_PREPARE_DATA.out.prepared_summary_csv
    nullhill_rdata      = DIVERSITY_NULL_HILL.out.nullhill_rdata
    filteredhill_rdata  = DIVERSITY_FILTERED_HILL.out.filteredhill_rdata
    anova_results       = DIVERSITY_PIPELINE_DIFF.out.anova_csv
    pattern_results     = DIVERSITY_FILTERED_VS_NULL.out.pattern_csv
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
