// modules/local/irma/main.nf
process IRMA {
    tag "$meta.id"
    label 'process_high'
    
    time '2h'
    memory '16.GB'
    cpus 8

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(reads)
    val virus_type

    output:
    tuple val(meta), path("*.fa"), emit: consensus
    tuple val(meta), path("reference_name.txt"), emit: reference
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    def input_cmd = reads instanceof List && reads.size() > 1 ?
        "${reads[0]} ${reads[1]}" :
        "${reads}"
    
    """
    # EJECUTAR IRMA PRIMERO (ignorar errores de salida)
    echo "Starting IRMA for ${meta.id}"
    IRMA $virus_type $input_cmd 01_irma $args || true
    
    # PROCESAR RESULTADOS
    REF_NAME="NO_MAPPING"
    HAS_CONSENSUS=false
    
    # Buscar VCF para referencia
    if [ -d "01_irma" ]; then
        VCF_FILE=\$(find 01_irma -name "*.vcf" 2>/dev/null | head -1)
        if [ -n "\$VCF_FILE" ]; then
            REF_NAME=\$(basename "\$VCF_FILE" .vcf)
            echo "Found reference: \$REF_NAME"
        fi
        
        # Buscar consensus
        CONSENSUS_FILE=\$(find 01_irma -name "*.fa" -o -name "*.fasta" 2>/dev/null | head -1)
        if [ -n "\$CONSENSUS_FILE" ] && [ -s "\$CONSENSUS_FILE" ]; then
            cp "\$CONSENSUS_FILE" ${prefix}_consensus.fa
            HAS_CONSENSUS=true
            echo "Found consensus: \$CONSENSUS_FILE"
        fi
    fi
    
    # CREAR OUTPUTS FINALES
    echo "\$REF_NAME" > reference_name.txt
    
    if [ "\$HAS_CONSENSUS" = "false" ]; then
        echo ">${prefix}_no_consensus" > ${prefix}_consensus.fa
        echo "NNNN" >> ${prefix}_consensus.fa
    fi
    
    echo "Final outputs:"
    echo "- Reference: \$REF_NAME"
    echo "- Consensus: \$HAS_CONSENSUS"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        irma: "1.3.0"
    END_VERSIONS
    """
}