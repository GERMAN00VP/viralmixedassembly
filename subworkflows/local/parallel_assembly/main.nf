include { IRMA } from '../../../modules/local/irma/main'
include { SPADES } from '../../../modules/nf-core/spades/main'
include { ABACAS } from '../../../modules/nf-core/abacas/main'

workflow SUBWORKFLOW_PARALLEL_ASSEMBLY {
    take:
    reads
    
    main:
    
    // Get virus type from params with RSV as default
    def virus_type = params.virus_type ?: "RSV"
    
    // Parallel assembly strategies
    IRMA(reads, virus_type)    // Reference-guided assembly with configurable virus type
    SPADES(reads)              // De novo assembly
    
    // Order SPAdes contigs using IRMA reference as guide
    ABACAS(SPADES.out.contigs, IRMA.out.reference)

    // Collect software versions
    ch_versions = Channel.empty()
    ch_versions = ch_versions.mix(IRMA.out.versions)
    ch_versions = ch_versions.mix(SPADES.out.versions)
    ch_versions = ch_versions.mix(ABACAS.out.versions)

    // Prepare MultiQC files
    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(IRMA.out.stats.map { meta, file -> file })
    ch_multiqc_files = ch_multiqc_files.mix(SPADES.out.contigs_stats.map { meta, file -> file })
    ch_multiqc_files = ch_multiqc_files.mix(ABACAS.out.stats.map { meta, file -> file })
    
    emit:
    // For internal use by next subworkflow
    versions         = ch_versions
    multiqc          = ch_multiqc_files
    // Assembly outputs for downstream analysis
    irma_consensus    = IRMA.out.consensus
    abacas_consensus  = ABACAS.out.ordered_contigs
    reference        = IRMA.out.reference           // Direct from IRMA
    irma_stats       = IRMA.out.stats
    spades_stats     = SPADES.out.contigs_stats
    abacas_stats     = ABACAS.out.stats
}