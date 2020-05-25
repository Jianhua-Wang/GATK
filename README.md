## GATK Best Practices

![](https://software.broadinstitute.org/gatk/img/pipeline_overview.png)

## Contents
- [Data Pre-processing](#1)
- [Germline SNPs + Indels (single sample)](#2)
- [Germline SNPs + Indels (cohort)](#3)
- [Somatic SNPs + Indels](#4)
- [Somatic CNVs](#5)

## <a name="1"></a>Data Pre-processing

### Purpose

The is the obligatory first phase that must precede all variant discovery. It involves pre-processing the raw sequence data (provided in FASTQ format) to produce analysis-ready BAM files. This involves alignment to a reference genome as well as some data cleanup operations to correct for technical biases and make the data suitable for analysis.

### Input

FASTQ format, Compressed or uncompressed, single end or paired end.

I used a small fragment (chr2:204300000-205000000) of a NGS data as the sample data (`test_1.fq.gz` and `test_2.fq.gz` in `input` folder).

### Output

BAM file and its index file ready for variant discovery

### Tools

[Minimap2](https://github.com/lh3/minimap2) (aligner), [SAMtools](http://samtools.sourceforge.net/), [GATK](https://github.com/broadinstitute/gatk/releases)

BWA has been commonly-used for alignment and recommended by GATK for years. But its developer Heng Li has developed a utralfast software called minimap2. So I switched from BWA to minimap2 in the following pipeline.

GATK is updated very frequently, while the latest version is not always the most suitable version, as updates not only include new features but also contain bugs. In this pipeline, I used version [4.1.3.0](https://github.com/broadinstitute/gatk/releases/tag/4.1.3.0).

Since GATK has many Python dependcies and both Minimap2 and SAMtools can be installed by Conda, it's quite simple and friendly for version control to install by creating conda environment. Run `set_up.sh` in `bin` folder will set up the environment automatically.

```shell
# anaconda installed
bash -i 00_set_up.sh
```

 ### Reference

GATK has constructed several series of reference files stored in [GATK bundle](ftp://ftp.broadinstitute.org/bundle/). 

It's up to you to choose which series for reference panel, b37, b36, hg18, hg19, or hg38. But it's necessary to use same series in both pre-processing and variant discovery. For example, b37 and hg19 belongs to the same Genome Build, however, the representation of chorosomes in these two series are different, b37 doesn't have the 'chr' prefix.

GATK bundle doesn't contain the index files of fasta file, as the index created by distinct tools are different. I use the b37 series as reference panel and have indexed the fasta file already. You can see them in `reference` folder.

We don't need every file in the GATK bundle, below are files needed in this pipeline. Download and decompressed them (GATK cannot recognize .gz files).

```
1000G_omni2.5.hg19.sites.vcf.gz
1000G_omni2.5.hg19.sites.vcf.idx.gz
dbsnp_138.hg19.vcf.gz
dbsnp_138.hg19.vcf.idx.gz
Mills_and_1000G_gold_standard.indels.hg19.sites.vcf.gz
Mills_and_1000G_gold_standard.indels.hg19.sites.vcf.idx.gz
1000G_phase1.snps.high_confidence.hg19.sites.vcf.gz
1000G_phase1.snps.high_confidence.hg19.sites.vcf.idx.gz
hapmap_3.3.hg19.sites.vcf.gz
hapmap_3.3.hg19.sites.vcf.idx.gz
```

`01_prepare_reference.sh` in `reference` folder can prepare the reference needed in pipeline.

### Usage

```shell
# set up
cd bin
bash 00_set_up.sh

# prepare reference
cd ../reference
bash 01_prepare_reference.sh

# data pre-processing
cd ../bin
bash 01_pre-processing.sh ../input/tumor_1.fq.gz ../input/tumor_2.fq.gz test
```

---

### Main steps

The pipeline provided by GATK was written in [WDL](https://software.broadinstitute.org/wdl/), which started from unmapped BAM (uBAM) format. Considering complexity of WDL and readability, I wrote this pipeiline in Shell which was a splice of several commands actually.

There are 4 steps in this pipeline. See below for details.

#### 1. Align

```shell
minimap2 \
-t minimap2_threads \
-R '@RG\tID:'${sample}'\tSM:'${sample}'\tLB:'${sample}'\tPL:Illumina' \
-ax sr \
../reference/human_g1k_v37.fasta.mmi $fq1 $fq2 | \
samtools view -S -b - > ./$sample/${sample}.bam
```

`-R '@RG\tID:'${sample}'\tSM:'${sample}'\tLB:'${sample}'\tPL:Illumina'` means adding read group label to output file, which is required by GATK. `AddOrReplaceReadGroups` in GATK can the same thing, either. The read group in BAM file looks like:

```shell
@RG	ID:test	SM:test	LB:test	PL:Illumina
```

And the output file was piped to `samtools view` to store in BAM format.

#### 2. Sort

```shell
samtools sort -@ $sort_threads -m $sort_memory -O bam -o ./${sample}/${sample}.sorted.bam ./${sample}/${sample}.bam
```

As the order of reads in the output of alignment is the order in the raw fastq files, we should sort them by the position on genome for further analysis. Turn up the `-@` and `-m` can speed up.

#### 3. Mark duplicates

```shell
$GATK \
MarkDuplicates \
-I ./${sample}/${sample}.sorted.bam \
-O ./${sample}/${sample}.markdup.bam \
-M ./${sample}/${sample}.markdup_metrics.txt

$samtools index ./${sample}/${sample}.markdup.bam
```

:bangbang:There shouldn't be any extra space in GATK command line.

If you are running out of memory, try reducing the value of `-SORTING_COLLECTION_SIZE_RATIO`  which is 0.25 by defualt.

##### Why mark duplicates?

During the library construction of NGS, PCR is one the significant steps which may yeild bias. PCR bias has many resources such as mismatching in PCR and the preference of PCR. To make sure the accuracy of variant calling, we need remove the duplicated reads made by PCR.

![](http://resources.qiagenbioinformatics.com/manuals/clcassemblycell/420/duplicate1.png)

You can use `samtools flagstat` to inspect how many duplicated reads are in the data.

```shell
samtools flagstat test.markdup.bam 
43961 + 0 in total (QC-passed reads + QC-failed reads)
0 + 0 secondary
155 + 0 supplementary
58 + 0 duplicates
43884 + 0 mapped (99.82% : N/A)
43806 + 0 paired in sequencing
21903 + 0 read1
21903 + 0 read2
43512 + 0 properly paired (99.33% : N/A)
43652 + 0 with itself and mate mapped
77 + 0 singletons (0.18% : N/A)
2 + 0 with mate mapped to a different chr
1 + 0 with mate mapped to a different chr (mapQ>=5)
```

There were 58 duplicated reads detected by GATK and GATK did not remove them. As the module's name, MarkDuplicates, the duplicated reads was marked by the flag (see [SAM format](https://samtools.github.io/hts-specs/SAMv1.pdf) for details).

#### 4. BQSR (Base Quality Score Recalibration)

```shell
$GATK \
BaseRecalibrator \
-R $REF/human_g1k_v37.fasta \
-I ./${sample}/${sample}.markdup.bam \
--known-sites $REF/dbsnp_138.b37.vcf \
--known-sites $REF/Mills_and_1000G_gold_standard.indels.b37.vcf \
-O ./${sample}/${sample}.recal_data.table

$GATK \
ApplyBQSR \
-R $REF/human_g1k_v37.fasta \
-I ./${sample}/${sample}.markdup.bam \
-bqsr ./${sample}/${sample}.recal_data.table \
-O ${OUTPUT}/${sample}.markdup.bqsr.bam
```

There are two steps in BQSR. First, generates recalibration table based on various
user-specified covariates (such as read group, reported quality score, machine cycle, and nucleotide context). The known polymorphic sites are used to exclude regions around known polymorphisms from analysis. Then, apply a linear base quality recalibration model trained with the BaseRecalibrator tool.

This is the lastest step of data pre-processing that detects systematic errors made by the sequencer when it estimates the quality score of each base call. Typically, the quality scores of bases are overrated. As this is a manul of pipeline, I won't talk too much about base recalibration here. And the technical details of BQSR can be found [here](https://gatkforums.broadinstitute.org/gatk/discussion/44/base-quality-score-recalibration-bqsr).![](https://us.v-cdn.net/5019796/uploads/FileUpload/d0/d306c3a2d28693598398b8c5443157.png)

---

## <a name="2"></a>Germline SNPs + Indels (single sample)

![](https://us.v-cdn.net/5019796/uploads/editor/uc/b3gutgxt2azd.png)

The main variant caller in GATK is HaplotypeCaller which has two modes, one for single sample and another for cohort sample. It's quite easy to select mode, if your have only one sample, use single sample mode, if not, use cohort mode (Joint call). Above is the new pipeline from GATK developed for single sample which involves deep learning is variants qaulity control.

### Input

Analysis-Ready Reads (BAM format as well as its index, output of pre-processing)

### Output

A variant information file (VCF) contains SNPs and Indels, along with its index

### Usage

```shell
# run 02_germline_snv_single_sample.sh and specify the bam file and sample name
cd bin
bash -i 02_germline_snv_single_sample.sh ../output/test.markdup.bqsr.bam test
```

---

### Main steps

#### 1. HaplotypeCaller

```shell
$GATK \
HaplotypeCaller \
-I $bam \
-R $REF/human_g1k_v37.fasta \
-D $REF/dbsnp_138.b37.vcf \
-O ${sample}/${sample}.HC.vcf
```

Call germline SNPs and indels via local re-assembly of haplotypes. Even in cohort mode, HaplotypeCaller is ran for once a sample, but in the 'GVCF' mode. I will describe it later. Wit this HMM tool, we got the initial output of short variation discovery. And a few QC steps are needed for high confidence.

#### 2. Annotate with CNNscore

```shell
$GATK \
CNNScoreVariants \
-I $bam \
-V ${sample}/${sample}.HC.vcf \
-R $REF/human_g1k_v37.fasta \
-O ${sample}/${sample}.HC.CNNscore.vcf \
-tensor-type read_tensor
```

Annotate a VCF with scores from a Convolutional Neural Network (CNN). This tool streams variants and their reference context to a python program, which evaluates a pre-trained neural network on each variant. 2D models convolve over aligned reads as well as the reference sequence, and variant annotations. 2D models require a SAM/BAM file as input and for the --tensor-type argument to be set to a tensor type which requires reads, as in the command above.

The annotated CNN_2D item looks like:

```shell
#CHROM  POS     ID      REF     ALT     QUAL    FILTER  INFO    FORMAT  test
2       204300244       .       TAA     T       139.10  PASS    AC=2;AF=1.00;AN=2;CNN_2D=5.774;DP=4;ExcessHet=3.0103;FS=0.000;MLEAC=2;MLEAF=1.00;MQ=60.00;QD=34.77;SOR=0.693    GT:AD:DP:GQ:PL  1/1:0,4:4:12:153,12,0
```

#### 3. Apply tranche filtering

```shell
$GATK \
FilterVariantTranches \
-V ${sample}/${sample}.HC.CNNscore.vcf \
-O ${OUTPUT}/${sample}.HC.CNNscore.filtered.vcf \
-resource $REF/hapmap_3.3.b37.vcf \
-resource $REF/1000G_omni2.5.b37.vcf \
-resource $REF/1000G_phase1.snps.high_confidence.b37.vcf \
-resource $REF/dbsnp_138.b37.vcf \
-resource $REF/Mills_and_1000G_gold_standard.indels.b37.vcf
```

Apply tranche filtering to VCF based on scores from an annotation in the INFO field. The annotation can come from the CNNScoreVariants tool (CNNLOD), VQSR (VQSLOD), or any other variant scoring tool which adds numeric annotations in a VCF's INFO field. Tranches are specified in percent sensitivity to the variants in the resource files.

 The default tranche filtering threshold for SNPs is 99.95 and for INDELs it is 99.4. You can custom the traches by `--snp-tranche` and `--indel-tranche`.

In our sample data, 4 SNPs out of 561 and 3 indels out of 201 were filtered.

```shell
19:53:04.160 INFO  FilterVariantTranches - Filtered 4 SNPs out of 561 and filtered 3 indels out of 201 with INFO score: CNN_2D.
```

#### 4. Functional annotate

There are many annotation tools, online or offline. GATK has its own annotator called Funcotator. I didn't include this part in the pipeline and if you are interested in Funcotator, see the [tutorial of Funcotator](https://software.broadinstitute.org/gatk/documentation/tooldocs/current/org_broadinstitute_hellbender_tools_funcotator_Funcotator.php).

---

## <a name="3"></a>Germline SNPs + Indels (cohort)

To be added :smile:

## <a name="4"></a>Somatic SNPs + Indels

According to the [GATK's Best Practice for somatic SNV + Indels discovery](https://software.broadinstitute.org/gatk/best-practices/workflow?id=11146), we can identify the somatic short variants with or without a matched normal sample.

### With matched normal sample

#### Input

Tumor bam, its index and matched normal bam, its index. These bam files should be pre-processed as described in [Data Pre-processing](#1). There is a tumor-normal pair for testing in the `input` directory.

#### Output

Filtered VCF and its index

:notes: Since the test data are too small to yield variants passed filtration, you will get no records in the output VCF file. However, it would work well for the real data in you got no error while testing.

#### Usage

```shell
# make sure your bam is pre-processed
cd bin
conda activate gatk
# bash bash 04_somatic_snv_turmor_normal.sh /path/of/tumor_bam tumor_sample_name /path/to/normal_bam normal_sample_name
# sample_name must be the @SM tag in the header of bam
bash bash 04_somatic_snv_turmor_normal.sh ../input/tumor.bam tumor ../input/normal.bam normal
conda deactivate
# about ten minutes for the testing data
```

#### Main steps

##### 1. Call candidate variants

Like HaplotypeCaller, Mutect2 calls SNVs and indels simultaneously via local de-novo assembly of haplotypes in an active region. That is, when Mutect2 encounters a region showing signs of somatic variation, it discards the existing mapping information and completely reassembles the reads in that region in order to generate candidate variant haplotypes.

```shell
$GATK Mutect2 \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-I $tumor_bam \
-I $normal_bam \
-normal $normal_sample \
--germline-resource $REF/af-only-gnomad.raw.sites.vcf \
--panel-of-normals $REF/Mutect2-WGS-panel-b37.vcf \
-O ${tumor_sample}/son.somatic.vcf.gz \
--bam-output ${tumor_sample}/bamout.bam \
--f1r2-tar-gz ${tumor_sample}/f1r2.tar.gz
```

:notes: Mutect2 supports more tumor samples from a single individual in a single run. If you have more tumor or normal samples, you should specify the `-I` and `-normal` option more than once.

##### 2. Calculate Contamination

This step emits an estimate of the fraction of reads due to cross-sample contamination for each tumor sample and an estimate of the allelic copy number segmentation of each tumor sample.

```shell
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

$GATK CalculateContamination \
-I ${tumor_sample}/tumor-pileups.table \
-matched ${tumor_sample}/normal-pileups.table \
-O ${tumor_sample}/contamination.table \
--tumor-segmentation ${tumor_sample}/segments.table
```

##### 3. Learn Orientation Bias Artifacts

This tool uses an optional F1R2 counts output of Mutect2 to learn the parameters of a model for orientation bias. It finds prior probabilities of single-stranded substitution errors prior to sequencing for each trinucleotide context. This is extremely important for FFPE tumor samples.

```shell
$GATK LearnReadOrientationModel \
-I ${tumor_sample}/f1r2.tar.gz \
-O ${tumor_sample}/artifact-priors.tar.gz
```

##### 4. Filter Variants

Mutect2’s somatic likelihoods model assumes that read errors are independent, so that, for example, four reads each with an error probability of 1/1000 yield a log odds of roughly 1000^4 in favor of being a real variant versus a sequencing error. 

```shell
$GATK FilterMutectCalls \
-R $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta \
-V ${tumor_sample}/son.somatic.vcf.gz \
-O ${tumor_sample}/son.somatic.filtered.vcf.gz \
--contamination-table ${tumor_sample}/contamination.table \
--tumor-segmentation ${tumor_sample}/segments.table \
--ob-priors ${tumor_sample}/artifact-priors.tar.gz \
-stats ${tumor_sample}/son.somatic.vcf.gz.stats \
--filtering-stats ${tumor_sample}/filtering.stats
```

##### 5. Filter alignment artifacts

FilterAlignmentArtifacts identifies alignment artifacts, that is, apparent variants due to reads being mapped to the wrong genomic locus.

```shell
$GATK FilterAlignmentArtifacts \
-V ${tumor_sample}/son.somatic.filtered.vcf.gz \
-I ${tumor_sample}/bamout.bam \
--bwa-mem-index-image $REF/Homo_sapiens_assembly19_1000genomes_decoy.fasta.img \
-O ${OUTPUT}/${tumor_sample}.somatic.filtered.aa.vcf.gz
```

### Without matched normal sample

Mutect2 can also run in tumor only mode. Here we use the PON provided by GATK as we don't have enough data to create PON (sample size > 40).

#### Input

Tumor bam, its index

#### Output

Filtered VCF and its index

Same as the tumor-normal pair section, the output of test data won't contain any records.

#### Usage

```shell
# make sure your bam is pre-processed
cd bin
conda activate gatk
# bash 05_somatic_snv_turmor_only.sh /path/of/tumor_bam tumor_sample_name
# tumor_sample_name can be set arbitrarily
bash 05_somatic_snv_turmor_only.sh ../input/tumor.bam tumor_only
conda deactivate
# about ten minutes for the testing data
```

#### Main steps

The main steps of this section are almost the same as last section. Just remove the parameters of normal sample. For exmple, we only run `GetPileupSummaries` on the tumor sample.

### Create panel of normal (PON)

When there is no matched normal sample for somatic mutation discovery, we need to create a panel of normal (PON) as a reference panel. GATK had made a PON that could be downloaded using `gsutil`.

```shell
# for WGS
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-WGS-panel-b37.vcf
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-WGS-panel-b37.vcf.idx

# for WES
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-exome-panel.vcf .
gsutil cp gs://gatk-best-practices/somatic-b37/Mutect2-exome-panel.vcf.idx .
```

Since the sizes of the bam files are huge (about 5T), either copying or downloading is very time-consuming, there is no test data and script for this section. If you want to create a PON, following the steps below or the [instruciton of GATK](https://software.broadinstitute.org/gatk/documentation/tooldocs/current/org_broadinstitute_hellbender_tools_walkers_mutect_CreateSomaticPanelOfNormals.php).

#### Main steps

##### 1. Run Mutect2 in tumor-only mode for each normal sample.

Note that as of May, 2019 -max-mnp-distance must be set to zero to avoid a bug in GenomicsDBImport.

```shell
gatk Mutect2 -R reference.fasta -I normal1.bam -max-mnp-distance 0 -O normal1.vcf.gz
```

##### 2. Create a GenomicsDB from the normal Mutect2 calls.

```shell
gatk GenomicsDBImport -R reference.fasta -L intervals.interval_list \
--genomicsdb-workspace-path pon_db \
-V normal1.vcf.gz \
-V normal2.vcf.gz \
-V normal3.vcf.gz
```

##### 3. Combine the normal calls using CreateSomaticPanelOfNormals.

```shell
gatk CreateSomaticPanelOfNormals -R reference.fasta -V gendb://pon_db -O pon.vcf.gz
```

## <a name="4"></a>Somatic CNVs

![](https://us.v-cdn.net/5019796/uploads/editor/dy/4ebxlije1ysh.png)

### Create PON

#### Pre-process intervals

```shell
../gatk-4.1.3.0/gatk PreprocessIntervals \
-R ../../../pip_ref_data/broad_references/b37/human_g1k_v37_decoy.fasta \
--bin-length 1000 \
--padding 0 \
-O preprocessed_intervals.interval_list
```

#### Annotate intervals

```shell
../gatk-4.1.3.0/gatk AnnotateIntervals \
-R ../../../pip_ref_data/broad_references/b37/human_g1k_v37_decoy.fasta \
-L preprocessed_intervals.interval_list \
--interval-merging-rule OVERLAPPING_ONLY \
-O annotated_intervals.tsv
```

#### Collect read counts for each sample

```shell
../gatk-4.1.3.0/gatk CollectReadCounts \ 
-L preprocessed_intervals.interval_list \
-I ../../../mulin/ref_data/1000G_high_coverage_bam/HG00096.wgs.ILLUMINA.bwa.GBR.high_cov_pcr_free.20140203.bam \
--interval-merging-rule OVERLAPPING_ONLY \
-O HG000096.counts.hdf5
```

#### 

### CNV calling (tumor sample only)



### CNV calling (tumor-normal pair)

