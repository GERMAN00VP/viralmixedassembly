
process IRMA {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        }"

    input:
    tuple val(meta), path(reads)
    val virus_type

    output:
    tuple val(meta), path("*.fa")          , emit: consensus
    tuple val(meta), path("reference.fasta"), emit: reference
    tuple val(meta), path("*.vcf")         , emit: vcf
    tuple val(meta), path("*.stats.txt")   , emit: stats
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Handle single-end vs paired-end
    def input_cmd = reads instanceof List && reads.size() > 1 ?
        "$reads" :
        "$reads"
    
    """
    mkdir -p irma_output
    
    # Run IRMA with specified virus type
    IRMA $virus_type $input_cmd irma_output
    
    # Copy consensus
    cp irma_output/amended_consensus/*.fa ${prefix}_consensus.fa
    
    # Extract reference from IRMA output
    REF_NAME=\$(ls irma_output/*.vcf | head -1 | xargs -n1 basename | cut -d . -f1)
    find references/ -name "\${REF_NAME}.fasta" -exec cp {} reference.fasta \\;
    
    # Copy VCF files
    cp irma_output/*.vcf ./
    
    # Generate basic stats
    echo "IRMA Assembly Statistics" > ${prefix}_stats.txt
    echo "Consensus length: \$(grep -v '>' ${prefix}_consensus.fa | tr -d '\\n' | wc -c)" >> ${prefix}_stats.txt
    echo "VCF variants: \$(find . -name '*.vcf' -exec cat {} \\; | grep -v '^#' | wc -l)" >> ${prefix}_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irma: \$(IRMA --version 2>&1 | head -1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_consensus.fa
    touch reference.fasta
    touch ${prefix}.vcf
    touch ${prefix}_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irma: \$(IRMA --version 2>&1 | head -1)
    END_VERSIONS
    """
}