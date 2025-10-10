include { IRMA } from '../../../modules/nf-core/irma/main' // TO DO
include { SPADES } from '../../../modules/nf-core/spades/main'
include { FETCH_REFERENCE } from '../../../modules/local/fetch_reference/main' // TO DO ? SI no se puede sacar directo de IRMA
include { ABACAS } from '../../../modules/nf-core/abacas/main'

workflow SUBWORKFLOW_PARALLEL_ASSEMBLY {
    take:
    reads
    
    main:
    
    // Ensamblajes en paralelo
    ch_irma_assembly = IRMA(reads)
    ch_spades_assembly = SPADES(reads)

    // Obtener referencia usada por IRMA
    ch_reference = FETCH_REFERENCE(ch_irma_assembly.out.reference)
    
    // Ordenar contigs con referencia como guía
    ch_spades_ordered = ABACAS(ch_spades_assembly.out.contigs, ch_reference)
    
    emit:
    irma_assembly    = ch_irma_assembly.consensus            // channel: [ val(meta), path(irma_assembly) ]
    spades_assembly  = ch_spades_ordered          // channel: [ val(meta), path(spades_assembly) ]
    reference        = ch_reference               // channel: [ path(reference_fasta) ]
    versions         = ch_versions.mix(
        IRMA.out.versions.first(),
        SPADES.out.versions.first(),
        FETCH_REFERENCE.out.versions.first(),
        ABACAS.out.versions.first()
    ).collect()                                   // channel: [ versions.yml ]
    multiqc          = ch_multiqc.mix(
        IRMA.out.stats.collect{ it[1] }.map{ [it] },
        SPADES.out.contigs_stats.collect{ it[1] }.map{ [it] },
        ABACAS.out.stats.collect{ it[1] }.map{ [it] }
    )                                             // channel: [ [ irma_stats ], [ spades_stats ], [ abacas_stats ] ]
}
