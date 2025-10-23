include { IRMA } from '../../../modules/local/irma/main'

workflow SUBWORKFLOW_PARALLEL_ASSEMBLY {
    take:
    reads
    
    main:
    
    def virus_type = params.virus_type ?: "RSV"
    IRMA(reads, virus_type)

    // Filtrar muestras que SÍ tuvieron mapeo
    successful_irma = IRMA.out.consensus.map { meta, consensus_file ->
        // Leer primera línea del consenso para ver si es vacío
        def first_line = consensus_file.readLines().first()
        def has_mapping = !first_line.contains("no_mapping") && !first_line.contains("NO_CONSENSUS")
        [meta, consensus_file, has_mapping]
    }.filter { meta, file, has_mapping -> has_mapping }
     .map { meta, file, has_mapping -> [meta, file] }

    // Referencias correspondientes a muestras exitosas
    successful_references = IRMA.out.reference.combine(successful_irma)
        .map { meta_ref, ref_file, meta_cons, cons_file -> 
            [meta_cons, ref_file] 
        }

    // Versiones (siempre emitir)
    ch_versions = IRMA.out.versions
    
    emit:
    versions       = ch_versions
    irma_consensus = successful_irma      // Solo muestras con mapeo
    reference      = successful_references // Solo referencias de muestras con mapeo
    all_irma_raw   = IRMA.out.consensus    // Todas las muestras (para debug)
}