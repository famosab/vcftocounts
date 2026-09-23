process DIVERSITY_PLOTS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6c/6c2dd8fc4240adf343ad71f9c56158d87f28b2577f2a6e114b7ab8406f0c4672/data'
        : 'community.wave.seqera.io/library/bioconductor-variantannotation_r-docopt_r-matrix:3cf2f20fdc477746'}"

    input:
    tuple val(meta), path(nullhill_rdata), path(filteredhill_rdata)

    output:
    tuple val(meta.id), glob("plots/**/*.{pdf,csv}"), emit: plots
    tuple val("${task.process}"), val('diversity_plots'), eval("echo 1.0.0"), topic: versions, emit: versions_diversity_plots

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    m07_plots.R \\
        --nullHill=${nullhill_rdata} \\
        --filteredHill=${filteredhill_rdata} \\
        --outdir=plots
    """

    stub:
    """
    mkdir -p plots
    touch plots/placeholder.pdf plots/placeholder.csv
    """
}