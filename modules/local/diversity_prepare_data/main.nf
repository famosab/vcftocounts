process DIVERSITY_PREPARE_DATA {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(filtered_csv), path(null_csv)
    path(demo_info)

    output:
    tuple val(meta), path("prepared.RData"), emit: prepared_rdata
    tuple val(meta), path("prepared_summary.csv"), emit: prepared_summary_csv
    tuple val("${task.process}"), val('diversity_prepare_data'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_prepare_data

    when:
    task.ext.when == null || task.ext.when

    script:
    def demo_arg = demo_info && !demo_info.isEmpty() ? "--demoInfo=${demo_info}" : ''
    """
    m01_prepare_data.R \\
        --filteredCSV=${filtered_csv} \\
        --nullCSV=${null_csv} \\
        --outdata=prepared.RData \\
        --outSummary=prepared_summary.csv \\
        ${demo_arg}
    """

    stub:
    """
    touch prepared.RData prepared_summary.csv
    """
}
