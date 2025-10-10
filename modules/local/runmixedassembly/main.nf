// modules/nf-core/runmixedassembly/main.nf

process RUNMIXEDASSEMBLY {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ghcr.io/german00vp/mixedassembly:0.1.4' :
        'ghcr.io/german00vp/mixedassembly:0.1.4' }"

    input:
    tuple val(meta), path(alignment), val(ref_id), path(priors)

    output:
    tuple val(meta), path("results/*.csv"), path("results/*.json"), path("results/*.fasta"), emit: results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def outdir = "results"

    """
    mkdir -p ${outdir}


    mixedassembly run-mixed-assembly \\
        --input ${alignment.toRealPath()} \\
        --ref ${ref_id} \\
        --prior ${priors.toRealPath()} \\
        --output_dir ${outdir} \\
        $args
    """

    stub:
    """
    mkdir -p results
    
    # STUB: Generar los MISMO nombres que el proceso real
    touch results/windows_trace.csv
    touch results/qc.json
    touch results/${meta.id}-MIX_ASSEMBLY.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mixedassembly: 0.1.4
    END_VERSIONS
    """
}

