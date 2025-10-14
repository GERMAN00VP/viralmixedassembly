include { KRAKEN2_KRAKEN2 } from '../../../modules/nf-core/kraken2/kraken2/main'
include { FASTQC as FASTQC_PRE } from '../../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_POST } from '../../../modules/nf-core/fastqc/main'
include { FASTP } from '../../../modules/nf-core/fastp/main'

workflow SUBWORKFLOW_PREPROCESS {
    take:
    reads

    main:
    // --- FASTQC (pre)
    FASTQC_PRE(reads)
    
    // --- FASTP
    def adapter_file = params.fasta_adapter ? file(params.fasta_adapter, checkIfExists: true) : null
    
    def fastp_input
    if (adapter_file) {
        fastp_input = reads.map { meta, read -> 
            [meta, read, adapter_file] 
        }
    } else {
        fastp_input = reads.map { meta, read -> 
            [meta, read, []] 
        }
    }

    FASTP(fastp_input, params.discard_trimmed_pass ?: false, params.save_trimmed_fail ?: false, params.save_merged ?: false)

    // --- KRAKEN2 (opcional)
    def db_path = params.kraken2_db ? file(params.kraken2_db, checkIfExists: true) : null
    def filtered_reads

    if (db_path) {
        KRAKEN2_KRAKEN2(
            FASTP.out.reads,
            db_path,
            params.save_output_fastqs ?: true,
            params.save_reads_assignment ?: true
        )
        filtered_reads = KRAKEN2_KRAKEN2.out.unclassified_reads_fastq
    } else {
        log.warn "⚠️  No Kraken2 database provided, skipping host filtering."
        filtered_reads = FASTP.out.reads
    }

    // --- FASTQC (post)
    FASTQC_POST(filtered_reads)

    // Preparar canales de salida
    ch_versions = Channel.empty()
    ch_versions = ch_versions.mix(FASTQC_PRE.out.versions)
    ch_versions = ch_versions.mix(FASTP.out.versions)
    if (db_path) {
        ch_versions = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions)
    }
    ch_versions = ch_versions.mix(FASTQC_POST.out.versions)

    // Para MultiQC - pasar archivos directamente
    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_PRE.out.zip.map { it -> it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { it -> it[1] })
    if (db_path) {
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.report.map { it -> it[1] })
    }
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_POST.out.zip.map { it -> it[1] })

    emit:
    reads    = filtered_reads
    versions = ch_versions.collectFile(
        storeDir: "${params.outdir}/pipeline_info",
        name: 'software_versions_subworkflow.yml',
        sort: true,
        newLine: true
    )
    multiqc  = ch_multiqc_files
}