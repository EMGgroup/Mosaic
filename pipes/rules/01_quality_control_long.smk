rule qualityCheckNanopore:
	input:
		raw_fastq=dirs_dict["RAW_DATA_DIR"]+"/{sample_nanopore}_nanopore.fastq",
	output:
		nanoqc_dir=temp(directory(dirs_dict["RAW_DATA_DIR"] + "/{sample_nanopore}_nanoplot")),
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report_preQC.html",
	message:
		"Performing nanoQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/env3.yaml"
#	threads: 1
	shell:
		"""
		nanoQC -o {output.nanoqc_dir} {input.raw_fastq}
		mv {output.nanoqc_dir}/nanoQC.html {output.nanoqc}
		"""

rule remove_adapters_quality_nanopore:
	input:
		raw_data=dirs_dict["RAW_DATA_DIR"] + "/{sample_nanopore}_nanopore.fastq",
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report.html"
	output:
		fastq=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq"),
		porechopped=temp(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_porechopped.fastq"),
		size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.txt"
	message:
		"Trimming Nanopore Adapters with Porechop"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env3.yaml"
	threads: 2
	shell:
		"""
		porechop -i {input.raw_data} -o {output.porechopped} --threads {threads}
		NanoFilt -q 10 -l 1000 --headcrop 50 {output.porechopped} > {output.fastq}
		grep -c "^@" fastq > {output} size
		"""
rule postQualityCheckNanopore:
	input:
		fastq=(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq"),
	output:
		nanoqc_dir=temp(directory(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanoplot_post")),
		nanoqc=dirs_dict["QC_DIR"] + "/{sample_nanopore}_nanopore_report_postQC.html",
	message:
		"Performing nanoQC statistics"
	conda:
		dirs_dict["ENVS_DIR"] + "/env3.yaml"
#	threads: 1
	shell:
		"""
		nanoQC -o {output.nanoqc_dir} {input.fastq}
		mv {output.nanoqc_dir}/nanoQC.html {output.nanoqc}
		"""
rule subsampleReadsNanopore:
	input:
		nano_sizes=expand(dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.txt", sample_nanopore=NANOPORE_SAMPLES),
		nanopore=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.tot.fastq",
	output:
		nanopore=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.sub.fastq",
		size=dirs_dict["CLEAN_DATA_DIR"] + "/{sample_nanopore}_nanopore_clean.sub.txt",
	message:
		"Subsampling Nanopore reads with BBtools"
	conda:
		dirs_dict["ENVS_DIR"]+ "/env1.yaml"
	params:
		min_depth=config['min_norm'],
		max_depth=config['max_norm'],
		sizes=dirs_dict["CLEAN_DATA_DIR"] + "/*_nanopore_clean.tot.txt"
	threads: 1
	resources:
		mem_mb=4000
	shell:
		"""
		nanopore=$( cat {params.sizes} | sort -n | head -1 )
		reformat.sh in={input.nanopore} out={output.nanopore} reads=$nanopore
		grep -c "^@" {output.nanopore} > {output.size}
		"""
