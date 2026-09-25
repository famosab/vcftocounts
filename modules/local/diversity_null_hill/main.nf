process DIVERSITY_NULL_HILL {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(prepared_rdata)
    path(demo_info)
    path(chunk_dir)

    output:
    tuple val(meta), path("nullhill.RData"), emit: nullhill_rdata
    tuple val(meta), path("chunks/*"), emit: chunk_dir
    tuple val("${task.process}"), val('diversity_null_hill'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_null_hill

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    m02_null_hill.R \\
        --in=${prepared_rdata} \\
        --out=nullhill.RData \\
        --chunkDir=${chunk_dir} \\
        ${demo_info ? "--demoInfo=${demo_info}" : ""}
    """

    stub:
    """
    mkdir -p chunks_null
    touch nullhill.RData
    """
}
