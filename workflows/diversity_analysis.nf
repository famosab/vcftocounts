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
include { DIVERSITY_ANALYSIS_PROCESS    } from '../modules/local/diversity_analysis'

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
    // Stage 1: Run unified diversity analysis
    // DIVERSITY_ANALYSIS_PROCESS expects: tuple val(meta), path(matrix_csv), path(samplesheet) + path(demo_info) + path(outdir)
    //
    // Map the matrix channel to create 3-tuples with the samplesheet and outdir
    def ch_samplesheet_path = ch_samplesheet.collect().first()
    
    def ch_matrix_for_diversity = ch_matrix.map { meta, matrix_csv ->
        [meta, matrix_csv, ch_samplesheet_path]
    }

    DIVERSITY_ANALYSIS_PROCESS(
        ch_matrix_for_diversity,
        ch_demo_info,
        channel.value(outdir)
    )

    emit:
    results_rdata     = DIVERSITY_ANALYSIS_PROCESS.out.results_rdata
    anova_csv         = DIVERSITY_ANALYSIS_PROCESS.out.anova_csv
    pattern_csv       = DIVERSITY_ANALYSIS_PROCESS.out.pattern_csv
    variance_rdata    = DIVERSITY_ANALYSIS_PROCESS.out.variance_rdata
    plots             = DIVERSITY_ANALYSIS_PROCESS.out.plots
    versions_diversity = DIVERSITY_ANALYSIS_PROCESS.out.versions_diversity_analysis
}
