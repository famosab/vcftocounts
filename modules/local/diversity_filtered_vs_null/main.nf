process DIVERSITY_FILTERED_VS_NULL {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(nullhill_rdata), path(filteredhill_rdata)

    output:
    tuple val(meta.id), path("patterns/*.csv"), emit: pattern_csv
    tuple val("${task.process}"), val('diversity_filtered_vs_null'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_filtered_vs_null

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    m05_filtered_vs_null.R \\
        --nullHill=${nullhill_rdata} \\
        --filteredHill=${filteredhill_rdata} \\
        --outdir=patterns
    """

    stub:
    """
    mkdir -p patterns
    touch patterns/filtered_vs_null.csv
    """
}