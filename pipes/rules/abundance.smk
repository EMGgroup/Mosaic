ruleorder: mapReadsToContigsPE > mapReadsToContigsSE
rule createContigBowtieDb:
	input:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.fasta",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.fasta"
	output:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.1.bt2",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.1.bt2"
	params:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}"
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		bowtie2-build -f {input.high_contigs} {params.high_contigs}
		bowtie2-build -f {input.low_contigs} {params.low_contigs}
		"""

rule mapReadsToContigsPE:
	input:
		high_bt2=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.1.bt2",
		low_bt2=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.1.bt2",
		forward_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_forward_paired_clean.{type}.fastq"),
		reverse_paired=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_reverse_paired_clean.{type}.fastq"),
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.{type}.fastq",
	output:
		high_sam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence.{type}.sam",
		low_sam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence.{type}.sam",
	params:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}"
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		bowtie2 --non-deterministic -x {params.high_contigs} -1 {input.forward_paired} -2 {input.reverse_paired} \
		-U {input.unpaired} -S {output.high_sam} 
		bowtie2 --non-deterministic -x {params.low_contigs} -1 {input.forward_paired} -2 {input.reverse_paired} \
		-U {input.unpaired} -S {output.low_sam} 
		"""
rule mapReadsToContigsSE:
	input:
		high_bt2=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.1.bt2",
		low_bt2=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.1.bt2",
		unpaired=dirs_dict["CLEAN_DATA_DIR"] + "/{sample}_unpaired_clean.{type}.fastq",
	output:
		high_sam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence.{type}.sam",
		low_sam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence.{type}.sam",
		high_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence.{type}.bam",
		low_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence.{type}.bam",
	params:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}"
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		bowtie2 --non-deterministic -x {params.high_contigs} -U {input.unpaired} -S {output.high_sam} 
		bowtie2 --non-deterministic -x {params.low_contigs} -U {input.unpaired} -S {output.low_sam} 
		samtools view -b -S {output.high_sam} > {output.high_bam}
		samtools view -b -S {output.low_sam} > {output.low_bam}
		"""
rule filterBAM:
	input:
		high_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence.{type}.bam",
		low_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence.{type}.bam",
	output:
		high_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered.{type}.bam",
		low_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered.{type}.bam",
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		bamm filter --bamfile {input.high_bam} --percentage_id 0.95 --percentage_aln 0.9
		bamm filter --bamfile {input.low_bam} --percentage_id 0.95 --percentage_aln 0.9
		"""
rule filterContigs:
	input:
		high_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered.{type}.bam",
		low_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered.{type}.bam",
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.fasta",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.fasta"
	output:
		high_bam_sorted=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered_sorted.{type}.bam",
		low_bam_sorted=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered_sorted.{type}.bam",
		high_bam_final=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered_sorted.{type}.bam",
		low_bam_final=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered_sorted.{type}.bam",
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		samtools sort {input.high_bam} -o {output.high_bam_sorted}
		samtools sort {input.low_bam} -o {output.low_bam_sorted}
		bedtools genomecov -dz -ibam {output.high_bam_sorted} 
		#get list of contigs and filter {output.high_bam_sorted} 
		"""

rule getAbundancesPE:
	input:
		high_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered.{type}.bam",
		low_bam=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered.{type}.bam",
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{type}.fasta",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{type}.fasta"
	output:
		high_bam_sorted=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered_sorted.{type}.bam",
		low_bam_sorted=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered_sorted.{type}.bam",
		high_bam_final=dirs_dict["VIRAL_DIR"]+ "/{sample}_high_confidence_filtered_sorted.{type}.bam",
		low_bam_final=dirs_dict["VIRAL_DIR"]+ "/{sample}_low_confidence_filtered_sorted.{type}.bam",
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		bamm 
		"""

