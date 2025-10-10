include { MAFFT_ALIGN } from '../../../modules/nf-core/mafft/align/main'
include { RUNMIXEDASSEMBLY } from '../../../modules/local/runmixedassembly/main'
include { PILON } from '../../../modules/nf-core/pilon/main'
include { SOLVE_FRAMESHIFTS } from '../../../modules/local/solve_frameshifts/main'

workflow SUBWORKFLOW_MERGE_CONSENSUS { 
    take:
    reads
    irma_results
    spades_results  
    reference
    
    // TO DO: Añadir los priors
    
    main:
    // Alinear ambos ensamblajes
    ch_aligned_assemblies = MAFFT_ALIGN(irma_results, spades_results)
    
    // Tu herramienta de merging
    ch_merged_consensus = RUNMIXEDASSEMBLY(ch_aligned_assemblies, reference)
    
    // Polish con lecturas originales
    ch_polished = PILON(ch_merged_consensus, reads) // Necesitarías pasar reads también
    
    // Corrección de frameshifts
    ch_final_consensus = SOLVE_FRAMESHIFTS(ch_polished)
    
    emit:
    consensus = ch_final_consensus                // channel: [ val(meta), path(consensus_fasta) ]
    stats     = RUNMIXEDASSEMBLY.out.stats        // channel: [ val(meta), path(merging_stats) ]
    versions  = ch_versions.mix(
        MAFFT_ALIGN.out.versions.first(),
        RUNMIXEDASSEMBLY.out.versions.first(),
        PILON.out.versions.first(),
        SOLVE_FRAMESHIFTS.out.versions.first()
    ).collect()                                   // channel: [ versions.yml ]
    // MultiQC opcional para este paso
    multiqc   = Channel.empty()                   // channel: [ ]
}