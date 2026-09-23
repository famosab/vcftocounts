process DIVERSITY_PIPELINE_DIFF {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(nullhill_rdata)

    output:
    tuple val(meta.id), path("anova/*.csv"), emit: anova_csv
    tuple val("${task.process}"), val('diversity_pipeline_diff'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_pipeline_diff

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    m04_pipeline_diff.R \\
        --nullHill=${nullhill_rdata} \\
        --outdir=anova
    """

    stub:
    """
    mkdir -p anova
    touch anova/pipeline_diff.csv
    """
}