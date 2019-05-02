rule downloadViralFiles:
	output:
		virSorter_db=protected(directory(config['virSorter_db'])),
		virSorter_dir=directory(config['virSorter_dir']),
		virFinder_dir=directory(config['virFinder_dir'])
	message:
		"Downloading required VirSorter and VirFinder data"
	threads: 1
	params:
		virSorter_db="db/VirSorter"
	shell:
		"""
		if [ ! -d {config[virSorter_dir]} ]
		then
			mkdir -p tools
			cd tools
			git clone https://github.com/simroux/VirSorter.git 
			cd VirSorter/Scripts 
			make clean
			make
			cd ../../../
		fi
		if [ ! -d {config[virSorter_db]} ]
		then
			curl -OL https://zenodo.org/record/1168727/files/virsorter-data-v2.tar.gz
			mkdir -p {params.virSorter_db}
			tar -xvzf virsorter-data-v2.tar.gz -C {params.virSorter_db}
			rm virsorter-data-v2.tar.gz
		fi
   		if [ ! -d {config[virFinder_dir]} ]
		then
			if [ ! {config[operating_system]} == "linux" ] 
			then
				curl -OL https://raw.github.com/jessieren/VirFinder/blob/master/mac/VirFinder_1.1.tar.gz?raw=true
			else
				curl -OL https://github.com/jessieren/VirFinder/blob/master/linux/VirFinder_1.1.tar.gz?raw=true
			fi
			mkdir -p {output.virFinder_dir}
			mv VirFinder*tar.gz* {output.virFinder_dir}/VirFinder_1.1.tar.gz
		fi
		"""

rule virSorter:
	input:
		representatives=dirs_dict["vOUT_DIR"] + "/merged_scaffolds_95-80.{sampling}.fna",
		virSorter_dir=config['virSorter_dir'],
		virSorter_db=config['virSorter_db']
	output:
		results=dirs_dict["VIRAL_DIR"] + "/virSorter_{sampling}/VIRSorter_global-phage-signal.csv"
	params:
		out_folder=dirs_dict["VIRAL_DIR"] + "/virSorter_{sampling}"
	message:
		"Classifing contigs with VirSorter"
	conda:
		dirs_dict["ENVS_DIR"] + "/vir.yaml"
	threads: 1
	shell:
		"""
		{config[virSorter_dir]}/wrapper_phage_contigs_sorter_iPlant.pl -f {input.representatives} \
			--db 2 \
			--wdir {params.out_folder} \
			--ncpu {threads} \
			--data-dir {input.virSorter_db} \
			--virome  
		"""

rule virFinder:
	input:
		scaffolds=dirs_dict["vOUT_DIR"] + "/merged_scaffolds_95-80.{sampling}.fna",
		virFinder_dir=config['virFinder_dir']
	output:
		pvalues=dirs_dict["VIRAL_DIR"] + "/virFinder_pvalues.{sampling}.txt"
	params:
		virFinder_script="scripts/virfinder_wrapper.R"
	message: 
		"Scoring virus VirFinder"
	conda:
		dirs_dict["ENVS_DIR"] + "/vir.yaml"
	threads: 1
	shell:
		"""
		Rscript {params.virFinder_script} {input.scaffolds} {output.pvalues}
		"""

rule getViralTable:
	input:
		pvalues = dirs_dict["VIRAL_DIR"] + "/virFinder_pvalues.{sampling}.txt",
		categories=dirs_dict["VIRAL_DIR"] + "/virSorter_{sampling}/VIRSorter_global-phage-signal.csv"
	output:
		circular_H=dirs_dict["VIRAL_DIR"]+ "/high_confidence_circular_list.{sampling}.txt",
		circular_L=dirs_dict["VIRAL_DIR"]+ "/low_confidence_circular_list.{sampling}.txt",
		non_circular_H=dirs_dict["VIRAL_DIR"]+ "/high_confidence_non_circular_list.{sampling}.txt",
		non_circular_L=dirs_dict["VIRAL_DIR"]+ "/low_confidence_non_circular_list.{sampling}.txt",
		circular_unk=dirs_dict["VIRAL_DIR"]+ "/unknown_circular_list.{sampling}.txt",
		table=dirs_dict["VIRAL_DIR"]+ "/viral_table.{sampling}.csv" 
	params:
		virFinder_script="scripts/virfinder_wrapper.R'",
		virFinder_dir=config['virFinder_dir']
	message: 
		"Parsing VirSorter and VirFinder results"
	threads: 1
	run:
		import pandas as pd
		results = pd.DataFrame(columns=('lenght', 'circular','type', 'VS_cat', 'VF_score', 'VF_pval'))


		#VirSorter
		VS = input.categories
		with open(VS) as fp:  
			line = fp.readline()
			cnt = 1
			while line:
				if line.startswith("#"):
					if (line.strip().split()[1].isdigit()):
						contig_type=(line.strip().split("-")[1])
				else:
					circular="N"
					contigName=line.split(",")[0].split("VIRSorter_")[1].replace(".", "_")
					category=line.split(",")[4]
					if "-circular" in contigName:
						contigName=contigName.split("-circular")[0]
						circular="Y"
					if "suggestCircular=yes" in contigName:
						circular="Y"
					results.loc[contigName, 'VS_cat'] = int(category)
					results.loc[contigName, 'circular'] = circular
					results.loc[contigName, 'type'] = contig_type
				line = fp.readline()
				cnt += 1
				
		#VirFinder
		VF = input.pvalues
		with open(VF) as fp:  
			line = fp.readline()
			cnt = 1
			while line:
				if cnt != 1:
					contigName=line.split("\t")[0].strip().replace(".", "_")
					contigLenght=line.split("\t")[1]
					contigScore=line.split("\t")[2]
					contigPval=line.split("\t")[3].split("\n")[0]
					results.loc[contigName, 'lenght'] = float(contigLenght)
					results.loc[contigName, 'VF_score'] = float(contigScore)
					results.loc[contigName, 'VF_pval'] = float(contigPval)
						#check if circular also
				line = fp.readline()
				cnt += 1	

		#filtering DFs
		df_A_c=results[results['VS_cat']<3][results['circular']=="Y"]
		df_B_c=results[results['VF_score']>0.9][results['VF_pval']<0.05][results['circular']=="Y"]
		df_C_c=results[results['VF_score']>0.7][results['VF_pval']<0.05][results['VS_cat']>0][results['circular']=="Y"]

		df_A_nc=results[results['VS_cat']<3][results['circular']!="Y"]
		df_B_nc=results[results['VF_score']>0.9][results['VF_pval']<0.05][results['circular']!="N"]
		df_C_nc=results[results['VF_score']>0.7][results['VF_pval']<0.05][results['VS_cat']>0][results['circular']=="N"]

		df_circular=results[results['circular']=="Y"]


		#joinin and dereplicating circular contigs
		lsA=(df_A_c.index.tolist())
		lsB=(df_B_c.index.tolist())
		lsC=(df_C_c.index.tolist())

		lsAnotB=set(lsA) - set(lsB)
		lsAB=lsA + list(lsAnotB)

		lsCnoAB=set(lsC) - set(lsAB)
		lsCf=list(lsCnoAB)
		print("circular")
		print("\n".join(lsCf))

		f=open(output.circular_H, 'w')
		f.write("\n".join(lsAB))
		f.close()

		f=open(output.circular_L, 'w')
		f.write("\n".join(lsCf))
		f.close()
		#dereplicating circular contigs

		lsCirc=df_circular.index.tolist()
		lsCircNothers=set(lsCirc) - set(lsA) - set(lsB) - set(lsC)

		f=open(output.circular_unk, 'w')
		f.write("\n".join(lsCircNothers))
		f.close()

		#joinin and dereplicating noncircular contigs
		lsA=(df_A_nc.index.tolist())
		lsB=(df_B_nc.index.tolist())
		lsC=(df_C_nc.index.tolist())

		lsAnotB=set(lsA) - set(lsB)
		lsAB=lsA + list(lsAnotB)

		lsCnoAB=set(lsC) - set(lsAB)
		lsCf=list(lsCnoAB)

		f=open(output.non_circular_H, 'w')
		f.write("\n".join(lsAB))
		f.close()

		f=open(output.non_circular_L, 'w')
		f.write("\n".join(lsCf))
		f.close()

		results.to_csv(table)

rule hmmCircularContigs:
	input:
		circular_unk=dirs_dict["VIRAL_DIR"]+ "/unknown_circular_list.{sampling}.txt"
	output:
		hmm_out=dirs_dict["VIRAL_DIR"]+ "/hmmsearch.{sampling}.out",
		hmm_list=dirs_dict["VIRAL_DIR"]+ "/positive_rep_list.{sampling}.txt"
	params:
		hmm="db/hmm/ssDNA.hmm"
	message:
		"Selecting Viral Circular Contigs with hmmsearch"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		hmmsearch {params.hmm} {input.circular_unk} -E 0.001 -T 50 > {output.hmm_out}
		grep {output.hmm_out} > {output.hmm_list}
		"""
rule extractViralContigs:
	input:
		representatives=dirs_dict["vOUT_DIR"] + "/merged_scaffolds_95-80.{sampling}.fna",
		circular_H=dirs_dict["VIRAL_DIR"]+ "/high_confidence_circular_list.{sampling}.txt",
		circular_L=dirs_dict["VIRAL_DIR"]+ "/low_confidence_circular_list.{sampling}.txt",
		non_circular_H=dirs_dict["VIRAL_DIR"]+ "/high_confidence_non_circular_list.{sampling}.txt",
		non_circular_L=dirs_dict["VIRAL_DIR"]+ "/low_confidence_non_circular_list.{sampling}.txt",
		circular_unk=dirs_dict["VIRAL_DIR"]+ "/unknown_circular_list.{sampling}.txt",
#		hmm_list=dirs_dict["VIRAL_DIR"]+ "/positive_rep_list.{sampling}.txt"
	output:
		high_contigs=dirs_dict["VIRAL_DIR"]+ "/high_confidence.{sampling}.fasta",
		low_contigs=dirs_dict["VIRAL_DIR"]+ "/low_confidence.{sampling}.fasta",
		edited_fasta=dirs_dict["VIRAL_DIR"] + "/merged_scaffolds_95-80.{sampling}.fna"
	message:
		"Selecting Viral Contigs"
	conda:
		dirs_dict["ENVS_DIR"] + "/env1.yaml"
	threads: 1
	shell:
		"""
		sed 's/\./_/g' {input.representatives} > {output.edited_fasta}
		seqtk subseq {output.edited_fasta} {input.circular_H} > {output.high_contigs}
		#seqtk subseq {output.hmm_list} {input.circular_unk} >> {output.high_contigs}
		sed -i 's/>/>Circular-/g' {output.high_contigs}
		seqtk subseq {output.edited_fasta} {input.non_circular_H} >> {output.high_contigs}
		seqtk subseq {output.edited_fasta} {input.circular_L} > {output.low_contigs}
		sed -i 's/>/>Circular-/g' {output.low_contigs}
		seqtk subseq {output.edited_fasta} {input.non_circular_L} >> {output.low_contigs}
		"""

			  

