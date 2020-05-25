#!/bin/bash

# # download
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/human_g1k_v37_decoy.dict.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/human_g1k_v37_decoy.fasta.fai.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/human_g1k_v37_decoy.fasta.gz

# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/1000G_omni2.5.b37.vcf.idx.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/1000G_omni2.5.b37.vcf.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/1000G_phase1.snps.high_confidence.b37.vcf.idx.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/1000G_phase1.snps.high_confidence.b37.vcf.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/hapmap_3.3.b37.vcf.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/hapmap_3.3.b37.vcf.idx.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/dbsnp_138.b37.vcf.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/dbsnp_138.b37.vcf.idx.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/Mills_and_1000G_gold_standard.indels.b37.vcf.gz
# wget -c ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/b37/Mills_and_1000G_gold_standard.indels.b37.vcf.idx.gz

# # decompress
# gzip -d human_g1k_v37_decoy.dict.gz
# gzip -d human_g1k_v37_decoy.fasta.fai.gz
# gzip -d human_g1k_v37_decoy.fasta.gz

# gzip -d 1000G_omni2.5.b37.vcf.idx.gz
# gzip -d 1000G_omni2.5.b37.vcf.gz
# gzip -d 1000G_phase1.snps.high_confidence.b37.vcf.idx.gz
# gzip -d 1000G_phase1.snps.high_confidence.b37.vcf.gz
# gzip -d hapmap_3.3.b37.vcf.gz
# gzip -d hapmap_3.3.b37.vcf.idx.gz
# gzip -d dbsnp_138.b37.vcf.gz
# gzip -d dbsnp_138.b37.vcf.idx.gz
# gzip -d Mills_and_1000G_gold_standard.indels.b37.vcf.gz
# gzip -d Mills_and_1000G_gold_standard.indels.b37.vcf.idx.gz

############################################################################################

# Above are the urls of reference in GATK bundle, however, the connection of the FTP is quite unstable
# So I recommand using the reference in FireCloud of GATK. It's on Google Storage and can be downloaded using gsutil without VPN

gsutil cp gs://broad-references/Homo_sapiens_assembly19_1000genomes_decoy/Homo_sapiens_assembly19_1000genomes_decoy.fasta .
gsutil cp gs://broad-references/Homo_sapiens_assembly19_1000genomes_decoy/Homo_sapiens_assembly19_1000genomes_decoy.dict .
gsutil cp gs://broad-references/Homo_sapiens_assembly19_1000genomes_decoy/Homo_sapiens_assembly19_1000genomes_decoy.fasta.fai .

gsutil cp gs://broad-references/hg19/v0/1000G_omni2.5.b37.vcf.gz .
gsutil cp gs://broad-references/hg19/v0/1000G_omni2.5.b37.vcf.gz.tbi .
gsutil cp gs://broad-references/hg19/v0/1000G_phase1.snps.high_confidence.b37.vcf.gz .
gsutil cp gs://broad-references/hg19/v0/1000G_phase1.snps.high_confidence.b37.vcf.gz.tbi .
gsutil cp gs://broad-references/hg19/v0/hapmap_3.3.b37.vcf.gz .
gsutil cp gs://broad-references/hg19/v0/hapmap_3.3.b37.vcf.gz.tbi .
gsutil cp gs://broad-references/hg19/v0/dbsnp_138.b37.vcf.gz .
gsutil cp gs://broad-references/hg19/v0/dbsnp_138.b37.vcf.gz.tbi .
gsutil cp gs://broad-references/hg19/v0/Mills_and_1000G_gold_standard.indels.b37.vcf.gz .
gsutil cp gs://broad-references/hg19/v0/Mills_and_1000G_gold_standard.indels.b37.vcf.gz.tbi .

gsutil cp gs://gatk-best-practices/somatic-b37/af-only-gnomad.raw.sites.vcf .
gsutil cp gs://gatk-best-practices/somatic-b37/af-only-gnomad.raw.sites.vcf.idx .
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-WGS-panel-b37.vcf .
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-WGS-panel-b37.vcf.idx .
gsutil cp gs://gatk-best-practices/somatic-b37/small_exac_common_3.vcf .
gsutil cp gs://gatk-best-practices/somatic-b37/small_exac_common_3.vcf.idx .

gsutil cp gs://gatk-test-data/cnv/somatic/wes-do-gc.pon.hdf5 .
gsutil cp gs://gatk-test-data/cnv/somatic/common_snps.interval_list .

# create minimap2 index
minimap2 -d Homo_sapiens_assembly19_1000genomes_decoy.fasta.mmi Homo_sapiens_assembly19_1000genomes_decoy.fasta

../bin/gatk-4.1.3.0/gatk BwaMemIndexImageCreator \
-I Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-O Homo_sapiens_assembly19_1000genomes_decoy.fasta.img