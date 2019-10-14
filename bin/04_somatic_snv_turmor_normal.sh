#!/bin/bash

########################################################

# GATK Best Practice
# Somatic SNPs + Indels (tumor-Normal pair)
# Author: Jianhua Wang (jianhua.mert@gmail.com)
# Date: 12-10-2019

########################################################

## parameters
INPUT=../input
OUTPUT=../output
tumor_bam=$1
tumor_sample=$2
normal_bam=$3
normal_sample=$4
REF=../reference

## tools
GATK=./gatk-4.1.3.0/gatk

########################################################

mkdir $tumor_sample

# Mutect2 call in tumor-normal mode
$GATK Mutect2 \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-I $tumor_bam \
-I $normal_bam \
-normal $normal_sample \
--germline-resource $REF/af-only-gnomad.raw.sites.vcf \
--panel-of-normals $REF/Mutect2-WGS-panel-b37.vcf \
-O ${tumor_sample}/${tumor_sample}.somatic.vcf.gz \
--bam-output ${tumor_sample}/bamout.bam \
--f1r2-tar-gz ${tumor_sample}/f1r2.tar.gz

$GATK GetPileupSummaries \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-I $tumor_bam \
--interval-set-rule INTERSECTION \
-V $REF/small_exac_common_3.vcf \
-L $REF/small_exac_common_3.vcf \
-O ${tumor_sample}/tumor-pileups.table

$GATK GetPileupSummaries \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-I $normal_bam \
--interval-set-rule INTERSECTION \
-V $REF/small_exac_common_3.vcf \
-L $REF/small_exac_common_3.vcf \
-O ${tumor_sample}/normal-pileups.table

$GATK LearnReadOrientationModel \
-I ${tumor_sample}/f1r2.tar.gz \
-O ${tumor_sample}/artifact-priors.tar.gz

$GATK CalculateContamination \
-I ${tumor_sample}/tumor-pileups.table \
-matched ${tumor_sample}/normal-pileups.table \
-O ${tumor_sample}/contamination.table \
--tumor-segmentation ${tumor_sample}/segments.table

$GATK FilterMutectCalls \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-V ${tumor_sample}/${tumor_sample}.somatic.vcf.gz \
-O ${tumor_sample}/${tumor_sample}.somatic.filtered.vcf.gz \
--contamination-table ${tumor_sample}/contamination.table \
--tumor-segmentation ${tumor_sample}/segments.table \
--ob-priors ${tumor_sample}/artifact-priors.tar.gz \
-stats ${tumor_sample}/${tumor_sample}.somatic.vcf.gz.stats \
--filtering-stats ${tumor_sample}/filtering.stats

$GATK FilterAlignmentArtifacts \
-V ${tumor_sample}/${tumor_sample}.somatic.filtered.vcf.gz \
-I ${tumor_sample}/bamout.bam \
--bwa-mem-index-image $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta.img \
-O ${OUTPUT}/${tumor_sample}.somatic.filtered.aa.vcf.gz

rm -rf $tumor_sample