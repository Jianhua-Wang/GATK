#!/bin/bash

########################################################

# GATK Best Practice
# Somatic SNPs + Indels (tumor Only)
# Author: Jianhua Wang (jianhua.mert@gmail.com)
# Date: 14-10-2019

########################################################

## parameters
INPUT=../input
OUTPUT=../output
tumor_bam=$1
tumor_sample=$2
REF=../reference

## tools
GATK=./gatk-4.1.3.0/gatk

########################################################

mkdir $tumor_sample
#Homo_sapiens_assembly19_1000genomes_decoy
# Pre-process intervals
$GATK PreprocessIntervals \
-L $REF/ice_targets.tsv.interval_list \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
--sequence-dictionary $REF/Homo_sapiens_assembly19_1000genomes_decoy.dict \
--bin-length 1000 \
--padding 250 \
--interval-merging-rule OVERLAPPING_ONLY \
-O $tumor_sample/preprocessed_intervals.interval_list

# $GATK PreprocessIntervals \
# -R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
# --bin-length 1000 \
# --padding 0 \
# -O $tumor_sample/preprocessed_intervals.interval_list

# Collect read counts for each sample
$GATK CollectReadCounts \
-L $tumor_sample/preprocessed_intervals.interval_list \
-I $tumor_bam \
--interval-merging-rule OVERLAPPING_ONLY \
-O $tumor_sample/${tumor_sample}.counts.hdf5

# Collects reference and alternate allele counts at specified sites
$GATK CollectAllelicCounts \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-L $REF/common_snps.interval_list \
-I $tumor_bam \
-O $tumor_sample/${tumor_sample}.allelicCounts.tsv

# Denoises read counts to produce denoised copy ratios
$GATK DenoiseReadCounts \
--standardized-copy-ratios $tumor_sample/${tumor_sample}.standardizedCR.tsv \
--count-panel-of-normals $REF/wes-do-gc.pon.hdf5 \
-I $tumor_sample/${tumor_sample}.counts.hdf5 \
--denoised-copy-ratios $tumor_sample/${tumor_sample}.denoisedCR.tsv

# Models segmented copy ratios from denoised read counts and 
# segmented minor-allele fractions from allelic counts
$GATK ModelSegments \
--allelic-counts $tumor_sample/${tumor_sample}.allelicCounts.tsv \
--denoised-copy-ratios $tumor_sample/${tumor_sample}.denoisedCR.tsv \
--output-prefix $tumor_sample \
-O $tumor_sample

# Calls copy-ratio segments as amplified, deleted, or copy-number neutral
$GATK CallCopyRatioSegments \
-I $tumor_sample/${tumor_sample}.cr.seg \
-O $tumor_sample/${tumor_sample}.called.seg

# Creates plots of denoised copy ratios
Rscript PlotDenoisedCopyRatios.R \
--sample_name $tumor_sample \
--standardized_copy_ratios_file $tumor_sample/${tumor_sample}.standardizedCR.tsv \
--denoised_copy_ratios_file $tumor_sample/${tumor_sample}.denoisedCR.tsv \
--contig_names=1CONTIG_DELIMITER2CONTIG_DELIMITER3CONTIG_DELIMITER4CONTIG_DELIMITER\
5CONTIG_DELIMITER6CONTIG_DELIMITER7CONTIG_DELIMITER8CONTIG_DELIMITER9CONTIG_DELIMITER\
10CONTIG_DELIMITER11CONTIG_DELIMITER12CONTIG_DELIMITER13CONTIG_DELIMITER14CONTIG_DELIMITER\
15CONTIG_DELIMITER16CONTIG_DELIMITER17CONTIG_DELIMITER18CONTIG_DELIMITER19CONTIG_DELIMITER\
20CONTIG_DELIMITER21CONTIG_DELIMITER22CONTIG_DELIMITERXCONTIG_DELIMITERY \
--contig_lengths=249250621CONTIG_DELIMITER243199373CONTIG_DELIMITER198022430CONTIG_DELIMITER\
191154276CONTIG_DELIMITER180915260CONTIG_DELIMITER171115067CONTIG_DELIMITER159138663CONTIG_DELIMITER\
146364022CONTIG_DELIMITER141213431CONTIG_DELIMITER135534747CONTIG_DELIMITER135006516CONTIG_DELIMITER\
133851895CONTIG_DELIMITER115169878CONTIG_DELIMITER107349540CONTIG_DELIMITER102531392CONTIG_DELIMITER\
90354753CONTIG_DELIMITER81195210CONTIG_DELIMITER78077248CONTIG_DELIMITER59128983CONTIG_DELIMITER\
63025520CONTIG_DELIMITER48129895CONTIG_DELIMITER51304566CONTIG_DELIMITER155270560CONTIG_DELIMITER59373566 \
--output_dir $tumor_sample \
--output_prefix $tumor_sample

# Creates plots of denoised copy ratios
Rscript PlotModeledSegments.R \
--sample_name $tumor_sample \
--denoised_copy_ratios_file $tumor_sample/${tumor_sample}.denoisedCR.tsv \
--allelic_counts_file $tumor_sample/${tumor_sample}.hets.tsv \
--modeled_segments_file $tumor_sample/${tumor_sample}.modelFinal.seg \
--contig_names=1CONTIG_DELIMITER2CONTIG_DELIMITER3CONTIG_DELIMITER4CONTIG_DELIMITER\
5CONTIG_DELIMITER6CONTIG_DELIMITER7CONTIG_DELIMITER8CONTIG_DELIMITER9CONTIG_DELIMITER\
10CONTIG_DELIMITER11CONTIG_DELIMITER12CONTIG_DELIMITER13CONTIG_DELIMITER14CONTIG_DELIMITER\
15CONTIG_DELIMITER16CONTIG_DELIMITER17CONTIG_DELIMITER18CONTIG_DELIMITER19CONTIG_DELIMITER\
20CONTIG_DELIMITER21CONTIG_DELIMITER22CONTIG_DELIMITERXCONTIG_DELIMITERY \
--contig_lengths=249250621CONTIG_DELIMITER243199373CONTIG_DELIMITER198022430CONTIG_DELIMITER\
191154276CONTIG_DELIMITER180915260CONTIG_DELIMITER171115067CONTIG_DELIMITER159138663CONTIG_DELIMITER\
146364022CONTIG_DELIMITER141213431CONTIG_DELIMITER135534747CONTIG_DELIMITER135006516CONTIG_DELIMITER\
133851895CONTIG_DELIMITER115169878CONTIG_DELIMITER107349540CONTIG_DELIMITER102531392CONTIG_DELIMITER\
90354753CONTIG_DELIMITER81195210CONTIG_DELIMITER78077248CONTIG_DELIMITER59128983CONTIG_DELIMITER\
63025520CONTIG_DELIMITER48129895CONTIG_DELIMITER51304566CONTIG_DELIMITER155270560CONTIG_DELIMITER59373566 \
--output_file $tumor_sample/${tumor_sample}.modeled.png

# rm -rf $tumor_sample