process DIVERSITY_ANALYSIS_PROCESS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(matrix_csv), path(samplesheet)
    path(demo_info)
    path(outdir)

    output:
    tuple val(meta), path("diversity_results.RData"),   emit: results_rdata
    tuple val(meta), path("anova_results.csv"),         emit: anova_csv
    tuple val(meta), path("pattern_results.csv"),       emit: pattern_csv
    tuple val(meta), path("variance.RData"),            emit: variance_rdata
    tuple val(meta), path("plots/*.pdf"),               emit: plots
    tuple val("${task.process}"), val('diversity_analysis'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_analysis

    when:
    task.ext.when == null || task.ext.when

    script:
    def demo_arg = demo_info && !demo_info.isEmpty() ? "--demoInfo=${demo_info}" : ''
    def numCores = task.cpus ?: 1
    """
    set -e
    export PATH="/home/ubuntu/miniconda3/envs/r-diversity/bin:\${PATH}"
    export CONDA_PREFIX=/home/ubuntu/miniconda3/envs/r-diversity
    
    diversity_analysis.R \\
        --matrixCSV=${matrix_csv} \\
        --samplesheet=${samplesheet} \\
        ${demo_arg} \\
        --outdir=${outdir} \\
        --numCores=${numCores}
    """

    stub:
    """
    mkdir -p plots
    touch diversity_results.RData anova_results.csv pattern_results.csv variance.RData plots/placeholder.pdf
    """
}
