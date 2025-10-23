/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap               } from 'plugin/nf-schema'

include { SUBWORKFLOW_PREPROCESS         } from '../subworkflows/local/preprocess/main'
include { SUBWORKFLOW_PARALLEL_ASSEMBLY  } from '../subworkflows/local/parallel_assembly/main'


include { paramsSummaryMultiqc           } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML         } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText         } from '../subworkflows/local/utils_nfcore_viralmixedassembly_pipeline'

include { MULTIQC                        } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VIRALMIXEDASSEMBLY {

    take:
    ch_samplesheet // channel: [ val(meta), path(reads) ]

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        EXECUTE SUBWORKFLOWS
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // 1. PREPROCESSING & HOST FILTERING
    SUBWORKFLOW_PREPROCESS(ch_samplesheet)


    // 2. PARALLEL ASSEMBLY STRATEGIES  
    SUBWORKFLOW_PARALLEL_ASSEMBLY(SUBWORKFLOW_PREPROCESS.out.reads)

   // COMENTADO TEMPORALMENTE - Descomenta cuando tengas estos subworkflows
    /*
    // 3. CONSENSUS MERGING & POLISHING
    SUBWORKFLOW_MERGE_CONSENSUS(
        SUBWORKFLOW_PARALLEL_ASSEMBLY.out.irma_consensus,  // CORRECCIÓN: irma_consensus no irma_assembly
        SUBWORKFLOW_PARALLEL_ASSEMBLY.out.spades_assembly,
        SUBWORKFLOW_PARALLEL_ASSEMBLY.out.reference
    )
    ch_versions = ch_versions.mix(SUBWORKFLOW_MERGE_CONSENSUS.out.versions)

    // 4. FINAL QUALITY CONTROL & REPORTING
    SUBWORKFLOW_MIXASSEMBLY_QC(SUBWORKFLOW_MERGE_CONSENSUS.out.consensus)
    ch_versions = ch_versions.mix(SUBWORKFLOW_MIXASSEMBLY_QC.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(SUBWORKFLOW_MIXASSEMBLY_QC.out.multiqc)
    */


    ch_versions = ch_versions.mix(SUBWORKFLOW_PREPROCESS.out.versions)
    ch_versions = ch_versions.mix(SUBWORKFLOW_PARALLEL_ASSEMBLY.out.versions)
    
    ch_multiqc_files = ch_multiqc_files.mix(SUBWORKFLOW_PREPROCESS.out.multiqc.collect())
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        MULTIQC & REPORTING INFRASTRUCTURE
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Collate software versions for MultiQC
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'software_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    // MultiQC configuration channels
    ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? 
        Channel.fromPath(params.multiqc_config, checkIfExists: true) : 
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ? 
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) : 
        Channel.empty()

    // Workflow summary for MultiQC
    summary_params      = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files    = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))

    // Methods description for MultiQC
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))

    // Combine all MultiQC inputs
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(
        name: 'methods_description_mqc.yaml',
        sort: true
    ))

    // Execute MultiQC
    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    preprocess        = SUBWORKFLOW_PREPROCESS.out.reads           // channel: [ val(meta), path(reads) ]
    consensus_irma    = SUBWORKFLOW_PARALLEL_ASSEMBLY.out.irma_consensus 
    multiqc_report    = MULTIQC.out.report.toList()                // channel: /path/to/multiqc_report.html
    versions          = ch_versions                                // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
