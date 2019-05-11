rule getORFs:
	input:
		contigs=dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence.{sampling}.fasta",
	output:
		coords=dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence.{sampling}.coords",
		aa=dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence_ORFs.{sampling}.fasta",
	message:
		"Calling ORFs with prodigal"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		prodigal -i {input.contigs} -o {output.coords} -a {output.aa} -p meta
		"""
rule clusterTaxonomy:
	input:
		aa=dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence_ORFs.{sampling}.fasta",
	output:
		out_dir=directory(dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence_vContact.{sampling}"),
		genome_file=dirs_dict["VIRAL_DIR"]+ "/{confidence}_confidence_genome_file.{sampling}.csv",
	params:
		clusterONE_dir=config["clusterONE_dir"],
		vcontact_dir=config["vcontact_dir"]
	message:
		"Clustering viral genomes with vContact2"
	conda:
		dirs_dict["ENVS_DIR"] + "/env4.yaml"
	threads: 8
	shell:
		"""
		if [ ! -d {params.clusterONE_dir} ]
		then 
			mkdir -p {params.clusterONE_dir}
			curl -OL  http://www.paccanarolab.org/static_content/clusterone/cluster_one-1.0.jar
			mv cluster_one-1.0.jar {params.clusterONE_dir}
		fi
		if [ ! -d {params.vcontact_dir} ]
		then
			git clone https://bitbucket.org/MAVERICLab/vcontact2/
			mv vcontact2 tools
			envir=$( which vcontact | rev | cut -d/ -f3 | rev)
			cp {params.vcontact_dir}/vcontact/data/ViralRefSeq-* .snakemake/conda/$envir/lib/python3.7/site-packages/vcontact/data/
		fi
		#three changes in code 1) int 2,3) summary remove excluded
		python ./{params.vcontact_dir}/vcontact/utilities/Gene2Genome.py -p {input.aa} -s Prodigal-FAA -o {output.genome_file}
		vcontact --raw-proteins {input.high_aa} --rel-mode 'Diamond' --proteins-fp {output.genome_file} \
		--db 'ProkaryoticViralRefSeq85-Merged' --pcs-mode MCL --vcs-mode MCL \
		--output-dir {output.out_dir} --threads {threads}
		"""