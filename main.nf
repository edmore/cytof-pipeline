/*
 * pipeline input parameters
 */
params.reads = "$projectDir/scripts/IH_Report_CyTOF_20230531.R"
params.outdir = "$projectDir"
log.info """\
    C Y T O F  P I P E L I N E
    ===================================
    reads        : ${params.reads}
    outdir       : ${params.outdir}
    """
    .stripIndent()

process CYTOFReport {
    script:
    """
    Rscript "${params.reads}"
    """
}

workflow {
    CYTOFReport()
}

workflow.onComplete {
    log.info ( workflow.success ? "\nDone! Open the following report in your browser --> $params.outdir/IH_report_CyTOF_53.T1_Normalized.fcs.pdf\n" : "Oops .. something went wrong" )
}