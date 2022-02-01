#!/bin/bash

# The following line causes bash to exit at any point if there is any error
# and to output each line as it is executed -- useful for debugging
set -e -x -o pipefail
if [ $skip == false ];
	then		
		#Grab inputs
		dx-download-all-inputs --parallel
		#Get reference genome
		dx cat project-ByfFPz00jy1fk6PjpZ95F27J:file-BxVGV9Q022qPQ5f2pbQYqbP4 | tar xf - # ~/hs37d5-fasta.tar -> ~/hs37d5.fa
		echo "ZIPPED truth VCF unzipping."
		#Unzip the vcf
		gzip -d ${VCF_path}
		#Remove the .gz suffix from truth_vcf filepath
		vcf_path=${VCF_path%.*}
		#install tabix
		apt-get install tabix
		#Zip VCFs
		bgzip $vcf_path
		#Following gzipping, append .gz to vcf filepath variables
		vcf_path=${vcf_path}.gz
		#Index VCFs
		tabix -p vcf ${vcf_path}
		#download docker file
		#The BCFtools docker image is used to convert the GVCF to VCF
		Docker_file_ID=project-ByfFPz00jy1fk6PjpZ95F27J:file-G55XqF00jy1QkJ174ZzZfzV5
  		dx download ${Docker_file_ID}

		Docker_image_file=$(dx describe ${Docker_file_ID} --name)
  		Docker_image_name=$(tar xfO "${Docker_image_file}" manifest.json | sed -E 's/.*"RepoTags":\["?([^"]*)"?.*/\1/')
		
		# make output folder
		mkdir -p ~/out/PRS_output/PRS_output

		vcf_name=${VCF_name%.g.vcf*}

		docker load < /home/dnanexus/"${Docker_image_file}"
  		echo "Using docker image ${Docker_image_name}"
		#Convert changes GVCF to VCF
		#-R flag is for regions of interest
		#-f reference genome
		#-0v uncompressed vcf
		#-o output name
  		docker run -v /home/dnanexus:/home/dnanexus --rm ${Docker_image_name} convert --gvcf2vcf -R $BEDfile_path -f /home/dnanexus/hs37d5.fa -Ov -o ~/out/PRS_output/PRS_output/${vcf_name}.vcf $vcf_path

		#save samplename
		samplename=$vcf_name

		#Set up FH docker image
		fh_docker_file_id=project-ByfFPz00jy1fk6PjpZ95F27J:file-G7p1PfQ0jy1bPBJP8kp0VGZp
		dx download ${fh_docker_file_id}

		fh_docker_image_file=$(dx describe ${fh_docker_file_id} --name)
		fh_docker_image_name=$(tar xfO "${fh_docker_image_file}" manifest.json | sed -E 's/.*"RepoTags":\["?([^"]*)"?.*/\1/')
		# load docker image
		docker load < /home/dnanexus/"${fh_docker_image_file}"

		# docker run. mount input directory as /sandbox, use the $vcf_name variable set above to create the docker path to mounted dir.
		# Output to output folder named $samplename.txt
		docker run -v /home/dnanexus:/home/dnanexus --rm ${fh_docker_image_name} ~/out/PRS_output/PRS_output/${vcf_name}.vcf > ~/out/PRS_output/PRS_output/$samplename.txt

		# Send output back to DNAnexus project
		mark-section "Upload output"
		dx-upload-all-outputs --parallel

		mark-success
fi
