import os
import glob
import yaml
### snakemake_workflows initialization ########################################
maindir = os.path.dirname(os.path.dirname(workflow.basedir))
#workflow_rscripts=os.path.join(maindir, "shared", "rscripts")
#shell.executable("/bin/bash")
## some internal functions  ###################################################
def load_configfile(configfile):
   with open(configfile, "r") as f:
       config = yaml.load(f, Loader=yaml.FullLoader)
   return(config)

def set_condaEnv():
    return{'CONDA_SHARED_ENV': 'env.yaml'}

def get_sample_names(infiles, ext, reads):
    """
    Get sample names without file extensions
    """
    s = set()
    lext = len(ext)
    l0 = len(reads[0])
    l1 = len(reads[1])
    for x in infiles:
        x = os.path.basename(x)[:-lext]
        if x.endswith(reads[0]):
            x = x[:-l0]
        elif x.endswith(reads[1]):
            x = x[:-l1]
        else:
            continue
        s.add(x)
    return sorted(list(s))

# update envs
globals().update(set_condaEnv())
# load config file
globals().update(load_configfile(workflow.overwrite_configfiles[0]))

## load samples
infiles = sorted(glob.glob(os.path.join(indir, '*'+ext)))
samples = get_sample_names(infiles,ext,reads)

### include modules of other snakefiles ########################################
################################################################################
include: os.path.join(workflow.basedir, "rules", "fastq_split_tchic.snakefile")
include: os.path.join(workflow.basedir, "rules", "fastq_map.snakefile")
include: os.path.join(workflow.basedir, "rules", "dedup_and_qc.snakefile")
include: os.path.join(workflow.basedir, "rules", "QC.snakefile")
include: os.path.join(workflow.basedir, "rules", "peakcall.snakefile")
if countRegions:
    include: os.path.join(workflow.basedir, "rules", "counting_sincei.snakefile")


### conditional/optional rules #################################################
################################################################################
def run_tchic_fastq(protocol):
    if protocol=='tchic':
        file_list = ["QC/tChIC_split_stats.png",
                     expand("FASTQ_RNA/{sample}{read}.fastq.gz", sample = samples, read = reads),
                     expand("FASTQ_OTHER/{sample}.BOTH{read}.fastq.gz", sample = samples, read = reads),
                     expand("FASTQ_OTHER/{sample}.NONE{read}.fastq.gz", sample = samples, read = reads)]
        return(file_list)
    else:
        return([])

def run_Trimming(trim):
    if trim:
        file_list = [
        expand("QC/FastQC_trimmed/{sample}{read}_fastqc.html", sample = samples, read = reads)
        ]
        return(file_list)
    else:
        return([])

def count_regions():
    if countRegions is not None:
        if countRegions == "windows":
            file_list = "counts/scCounts_"+binSize+"bp_bins.loom"
        if countRegions == "peaks" or countRegions == "bed":
            file_list = "counts/scCounts_"+countRegions+".loom"
        return(file_list)
    else:
        return([])

def meth_check():
    file_list = [
    expand("dedup_bam/{sample}.bam", sample = samples),
    expand("dedup_bam/{sample}.bam.bai", sample = samples),
    expand("coverage/{sample}_dedup.cpm.bw", sample = samples),
    "QC/featureEnrichment.png",
    "QC/featureEnrichment_biotype.png"]
    if len(samples) > 1:
        file_list.extend(["QC/bwSummary_bins.npz",
                        "QC/cor-spearman_bins.png"])
    return(file_list)

### main rule ##################################################################
################################################################################
#localrules: FASTQ#1, FASTQ2
rule all:
    input:
        run_tchic_fastq(protocol),
        run_Trimming(trim),
        expand("QC/FastQC/{sample}{read}_fastqc.html", sample = samples, read=reads),
        expand("mapped_bam/{sample}.bam", sample = samples),
        expand("mapped_bam/{sample}.bam.bai", sample = samples),
        meth_check(),
        count_regions(),
        "QC/plate_plots.pdf",
        "QC/scFilterStats.txt",
        "QC/multiqc_report.html"

### execute after workflow finished ############################################
################################################################################
onsuccess:
    if "verbose" in config and config["verbose"]:
        print("\n--- scChICflow finished successfully! ------------------\n")
onerror:
    print("\n !!!! ERROR in scChIC workflow! !!!!\n")
