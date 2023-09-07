/*
 * pipeline input parameters
 */
params.reads = "$projectDir/main.R"
params.outdir = "ourDesiredOutputDir"
log.info """\
    C Y T O F  P I P E L I N E
    ===================================
    reads        : ${params.reads}
    outdir       : ${params.outdir}
    integration : ${params.integration}
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
    log.info ( workflow.success ? "\nDone! Your report can be found at this location --> $params.outdir/IH_report_CyTOF_53.T1_Normalized.fcs.pdf\nIntegration params --> $params.integration\n" : "Oops .. something went wrong" )
}