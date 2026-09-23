process CSV_TO_DIVERSITY_FORMAT {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(matrix_csv), path(samplesheet)

    output:
    tuple val(meta.id), path("filtered_counts.csv"), emit: filtered_csv
    tuple val(meta.id), path("null_counts.csv"),     emit: null_csv
    tuple val("${task.process}"), val('csv_to_diversity_format'), eval("echo 1.0.0"), topic: versions, emit: versions_csv_to_diversity_format

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    csv_to_diversity_format.R \\
        --matrix=${matrix_csv} \\
        --samplesheet=${samplesheet} \\
        --outFiltered=filtered_counts.csv \\
        --outNull=null_counts.csv
    """

    stub:
    """
    touch filtered_counts.csv null_counts.csv
    """
}