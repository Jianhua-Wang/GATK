#!/bin/bash

########################################################

# GATK Best Practice
# Germline SNPs + Indels (single sample)
# Author: Jianhua Wang (jianhua.mert@gmail.com)
# Date: 19-08-2019

########################################################

## parameters
INPUT=../input
OUTPUT=../output
bam=$1
sample=$2
REF=../reference

## tools
GATK=./gatk-4.1.3.0/gatk
bwa=./bwa-0.7.17/bwa
samtools=./samtools-1.9/samtools

#########################################################

mkdir $sample

# HaplotypeCaller
$GATK \
HaplotypeCaller \
-I $bam \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-D $REF/dbsnp_138.b37.vcf.gz \
-O ${sample}/${sample}.HC.vcf

# CNNscore
$GATK \
CNNScoreVariants \
-I $bam \
-V ${sample}/${sample}.HC.vcf \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-O ${sample}/${sample}.HC.CNNscore.vcf \
-tensor-type read_tensor

# Apply filter
$GATK \
FilterVariantTranches \
-V ${sample}/${sample}.HC.CNNscore.vcf \
-O ${OUTPUT}/${sample}.HC.CNNscore.filtered.vcf.gz \
-resource $REF/hapmap_3.3.b37.vcf.gz \
-resource $REF/1000G_omni2.5.b37.vcf.gz \
-resource $REF/1000G_phase1.snps.high_confidence.b37.vcf.gz \
-resource $REF/dbsnp_138.b37.vcf.gz \
-resource $REF/Mills_and_1000G_gold_standard.indels.b37.vcf.gz

rm -rf $sample