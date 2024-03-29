if protocol == "chic":
    rule FASTQ:
          input:
              r1=indir+"/{sample}"+reads[0]+ext,
              r2=indir+"/{sample}"+reads[1]+ext
          output:
              r1="FASTQ/{sample}"+reads[0]+".fastq.gz",
              r2="FASTQ/{sample}"+reads[1]+".fastq.gz"
          shell:
              "( [ -f {output.r1} ] || ln -s -r {input.r1} {output.r1} ) && \
               ( [ -f {output.r2} ] || ln -s -r {input.r2} {output.r2} )"
else:
    rule split_tChIC:
        input:
            r1=indir+"/{sample}"+reads[0]+ext,
            nla=barcode_list,
            cs2=barcodes_cs2
        output:
            cs2=temp("{sample}.CS2.txt"),
            nla=temp("{sample}.NLA.txt"),
            both=temp("{sample}.BOTH.txt"),
            none=temp("{sample}.NONE.txt"),
            log="QC/{sample}_split_tChIC.log"
        log: "logs/split_tChIC_{sample}.err"
        params:
            script = os.path.join(workflow.basedir, "tools", "split_fastq.py"),
            prefix="{sample}"
        threads: 10
        resources:
            mem_mb=20000
        shell:
            "{params.script} --ncpus={threads} --infile={input.r1} --prefix={params.prefix} \
            --nla_bc={input.nla} --celseq_bc={input.cs2} > {output.log} 2> {log}"

    split_cmd="filterbyname.sh -Xmx50g include=t in={input.r1} in2={input.r2} \
        out={output.r1} out2={output.r2} names={input.names} > {log} 2>&1"

    rule split_fastq_dna:
        input:
            r1=indir+"/{sample}"+reads[0]+ext,
            r2=indir+"/{sample}"+reads[1]+ext,
            names="{sample}.NLA.txt"
        output:
            r1="FASTQ/{sample}"+reads[0]+".fastq.gz",
            r2="FASTQ/{sample}"+reads[1]+".fastq.gz"
        log: "logs/dnaSplit_{sample}.log"
        shell:
            split_cmd

    rule split_fastq_rna:
        input:
            r1=indir+"/{sample}"+reads[0]+ext,
            r2=indir+"/{sample}"+reads[1]+ext,
            names="{sample}.CS2.txt"
        output:
            r1="FASTQ_RNA/{sample}"+reads[0]+".fastq.gz",
            r2="FASTQ_RNA/{sample}"+reads[1]+".fastq.gz"
        log: "logs/rnaSplit_{sample}.log"
        shell:
            split_cmd

    rule split_fastq_both:
        input:
            r1=indir+"/{sample}"+reads[0]+ext,
            r2=indir+"/{sample}"+reads[1]+ext,
            names="{sample}.BOTH.txt"
        output:
            r1="FASTQ_OTHER/{sample}.BOTH"+reads[0]+".fastq.gz",
            r2="FASTQ_OTHER/{sample}.BOTH"+reads[1]+".fastq.gz"
        log: "logs/bothSplit_{sample}.log"
        shell:
            split_cmd

    rule split_fastq_none:
        input:
            r1=indir+"/{sample}"+reads[0]+ext,
            r2=indir+"/{sample}"+reads[1]+ext,
            names="{sample}.NONE.txt"
        output:
            r1="FASTQ_OTHER/{sample}.NONE"+reads[0]+".fastq.gz",
            r2="FASTQ_OTHER/{sample}.NONE"+reads[1]+".fastq.gz"
        log: "logs/noneSplit_{sample}.log"
        shell:
            split_cmd

    rule plot_numbers:
        input: expand("QC/{sample}_split_tChIC.log", sample=samples)
        output: "QC/tChIC_split_stats.png"
        params:
            indir = "QC",
            rscript = os.path.join(workflow.basedir, "tools", "plot_tChIC_split.R")
        shell:
            "Rscript {params.rscript} {output} {params.indir}"
