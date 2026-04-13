#!/bin/bash
set -e

############################
# CONFIG + LOGGING
############################

CONFIG="config/config.yaml"

mkdir -p logs
LOG_FILE="logs/pipeline.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

############################
# SETUP DIRECTORIES
############################

mkdir -p data/raw data/reference
mkdir -p results/{qc,alignment,variants,annotation,reports}

############################
# STEP 0: READ CONFIG (SAFE YAML PARSING)
############################

log "STEP 0: Reading configuration file"

eval "$(python3 - <<EOF
import yaml

with open("$CONFIG") as f:
    config = yaml.safe_load(f)

print(f'fastq_1="{config["fastq_1"]}"')
print(f'fastq_2="{config["fastq_2"]}"')
print(f'reference="{config["reference"]}"')
EOF
)"

############################
# STEP 1: CONDA ENV SETUP
############################

log "STEP 1: Setting up conda environment"

source "$(conda info --base)/etc/profile.d/conda.sh"

if ! conda env list | grep -q "ngs_pipeline_env"; then
    log "Creating conda environment from environment.yml"
    conda env create -f environment.yml
else
    log "Environment already exists"
fi

conda activate ngs_pipeline_env
############################
# STEP 2: DOWNLOAD FASTQ (FIXED)
############################

log "STEP 2: Downloading FASTQ files"

cd data/raw

SRR="SRR789974"

if [[ ! -f ${SRR}_1.fastq.gz || ! -f ${SRR}_2.fastq.gz ]]; then

    log "Using stable HTTPS download (no FTP)"

    wget -c --tries=10 --timeout=30 \
    https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR789/SRR789974/SRR789974_1.fastq.gz

    wget -c --tries=10 --timeout=30 \
    https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR789/SRR789974/SRR789974_2.fastq.gz

else
    log "FASTQ files already exist"
fi

cd ../../

############################
# STEP 3: QUALITY CONTROL
############################

log "STEP 3: FastQC"

fastqc "$fastq_1" "$fastq_2" -o results/qc/

############################
# STEP 4: REFERENCE GENOME
############################

log "STEP 4: Preparing reference genome"

cd data/reference

if [[ ! -f chr22.fa ]]; then
    wget -c http://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr22.fa.gz
    gunzip -f chr22.fa.gz
fi

cd ../../

############################
# STEP 5: INDEX REFERENCE
############################

log "STEP 5: Indexing reference genome"

bwa index "$reference"

############################
# STEP 6: ALIGNMENT
############################

log "STEP 6: Alignment with BWA"

bwa mem "$reference" "$fastq_1" "$fastq_2" > results/alignment/aligned.sam

############################
# STEP 7: BAM PROCESSING
############################

log "STEP 7: SAM to BAM"

samtools view -Sb results/alignment/aligned.sam > results/alignment/aligned.bam
samtools sort results/alignment/aligned.bam -o results/alignment/sorted.bam
samtools index results/alignment/sorted.bam

rm -f results/alignment/aligned.sam results/alignment/aligned.bam

############################
# STEP 8: VARIANT CALLING
############################

log "STEP 8: Variant calling"

bcftools mpileup -f "$reference" results/alignment/sorted.bam | \
bcftools call -mv -o results/variants/variants.vcf

############################
# STEP 9: FILTER VARIANTS
############################

log "STEP 9: Filtering variants"

bcftools filter -e 'QUAL<20' results/variants/variants.vcf \
    -Oz -o results/variants/filtered.vcf.gz

bcftools index results/variants/filtered.vcf.gz

############################
# STEP 10: MUTATION ANALYSIS
############################

log "STEP 10: Mutation analysis"

bcftools view results/variants/filtered.vcf.gz | grep -v "^#" | \
cut -f4,5 | sort | uniq -c > results/reports/mutation_types.txt

awk '{print $2"→"$3, $1}' results/reports/mutation_types.txt \
> results/reports/formatted_mutations.txt

bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\n' \
results/variants/filtered.vcf.gz > results/reports/variants_table.txt

############################
# STEP 11: SNP + INDEL SEPARATION
############################

log "STEP 11: SNP and INDEL separation"

bcftools view -v snps results/variants/filtered.vcf.gz > results/variants/snps.vcf
bcftools view -v indels results/variants/filtered.vcf.gz > results/variants/indels.vcf

############################
# STEP 12: ANNOTATION
############################

log "STEP 12: Annotation with snpEff"

SNPEFF_JAR=$(find "$CONDA_PREFIX/share" -name "snpEff.jar" | head -n 1)

java -Xmx4g -jar "$SNPEFF_JAR" GRCh38.86 \
results/variants/filtered.vcf.gz > results/annotation/annotated.vcf

############################
# STEP 13: SUMMARY
############################

log "STEP 13: Generating summary"

echo "Missense: $(grep -c missense_variant results/annotation/annotated.vcf)" \
> results/reports/final_summary.txt

echo "Synonymous: $(grep -c synonymous_variant results/annotation/annotated.vcf)" \
>> results/reports/final_summary.txt

echo "Intergenic: $(grep -c intergenic_region results/annotation/annotated.vcf)" \
>> results/reports/final_summary.txt

############################
# DONE
############################
log "Pipeline completed successfully"

