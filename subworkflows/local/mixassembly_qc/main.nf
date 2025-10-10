include { SORT_OUT_FILES } from '../../../modules/local/sort_out_files/main'
include { NEXTCLADE_DATASETGET } from '../../../modules/nf-core/nextclade/datasetget/main'
include { NEXTCLADE_RUN } from '../../../modules/nf-core/nextclade/run/main'
include { MIXEDASSEMBLY_QC } from '../../../modules/local/mixedassembly_qc/main' // TO DO

workflow SUBWORKFLOW_MIXASSEMBLY_QC {
    take:
    consensus
    stats // The qc.json files created by RUNMIXEDASSEMBLY
    
    main:
    // Organizar archivos de salida
    ch_sorted_files = SORT_OUT_FILES(consensus,stats)
    
    // Análisis con Nextclade (paralelo: descarga dataset y ejecución)
    ch_nextclade_db = NEXTCLADE_DATASETGET()
    ch_nextclade_results = NEXTCLADE_RUN(ch_sorted_files.consensus_fasta, ch_nextclade_db)
    
    // QC específico de tu pipeline
    ch_qc_report = MIXEDASSEMBLY_QC(ch_sorted_files, ch_nextclade_results) // TO DO
    
    
    emit:
    reports   = ch_qc_report                     // channel: [ val(meta), path(qc_report) ]
    versions  = ch_versions.mix(
        SORT_OUT_FILES.out.versions.first(),
        NEXTCLADE_DATASETGET.out.versions.first(),
        NEXTCLADE_RUN.out.versions.first(),
        MIXEDASSEMBLY_QC.out.versions.first()
    ).collect()                                  // channel: [ versions.yml ]
    multiqc   = ch_multiqc.mix(
        NEXTCLADE_RUN.out.results.collect{ it[1] }.map{ [it] },
    )                                            // channel: [ [ nextclade_results ] ]
}