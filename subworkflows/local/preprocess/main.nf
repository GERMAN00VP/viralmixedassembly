

include { FASTQC                         } from '../../../modules/nf-core/fastqc/main'
include { FASTP                          } from '../../../modules/nf-core/fastp/main'   
include { KRAKEN2_KRAKEN2                } from '../../../modules/nf-core/kraken2/kraken2/main' 


workflow SUBWORKFLOW_PREPROCESS {
    take:
    reads
    
    main:
    // FASTQC inicial
    FASTQC(reads)
    
    // Quality trimming
    FASTP(reads)
    
    // Host removal
    KRAKEN2_KRAKEN2(FASTP.out.reads, [], [], [])
    
    // FASTQC post-filtering
    FASTQC(KRAKEN2_KRAKEN2.out.unclassified)
    
    emit:
    reads     = KRAKEN2_KRAKEN2.out.unclassified  // channel: [ val(meta), path(reads) ]
    versions  = ch_versions.mix(
        FASTQC.out.versions.first(),
        FASTP.out.versions.first(), 
        KRAKEN2_KRAKEN2.out.versions.first()
    ).collect()                                    // channel: [ versions.yml ]
    multiqc   = ch_multiqc.mix(
        FASTQC.out.zip.collect{ it[1] }.map{ [it] },
        FASTP.out.json.collect{ it[1] }.map{ [it] },
        KRAKEN2_KRAKEN2.out.report.collect{ it[1] }.map{ [it] }
    )                                             // channel: [ [ fastqc_data ], [ fastp_json ], [ kraken2_report ] ]
}
