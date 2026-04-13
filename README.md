# NGS Variant Calling Pipeline

## Overview
This project implements an automated end-to-end Next Generation Sequencing (NGS) pipeline for variant calling, starting from raw paired-end FASTQ files and producing annotated variants.

---

## Dataset

- Sample ID: HG03714  
- Population: Indian Telugu in the UK (ITU)  
- BioSample ID: SAMEA1839809  
- Sequencing Type: Low-coverage WGS  
- Reference Genome: GRCh38 (chr22)

---

## Pipeline Workflow

```
FASTQ → QC → Alignment → BAM → Variant Calling → Filtering → Annotation → Reports
```

---

## Tools Used

- FastQC  
- BWA  
- Samtools  
- BCFtools  
- SnpEff  
 

---

## Project Structure

```
ngs-variant-calling-pipeline/
│── scripts/
│   └── run_pipeline.sh
│── config/
│   └── config.yaml
│── data/
│   ├── raw/
│   └── reference/
│── results/
│── .gitignore
│── README.md
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/bushra-rahman588/ngs-variant-calling-pipeline.git
cd ngs-variant-calling-pipeline
```

Create environment:

```bash
conda env create -f environment.yml
conda activate ngs_pipeline_env
```

---

## Configuration

Create config file:

```bash
mkdir -p config
nano config/config.yaml
```

Paste this:

```yaml
sample_name: HG03714

fastq_1: data/raw/SRR789974_1.fastq.gz
fastq_2: data/raw/SRR789974_2.fastq.gz

reference: data/reference/chr22.fa

qc_dir: results/qc
alignment_dir: results/alignment
variants_dir: results/variants
annotation_dir: results/annotation
reports_dir: results/reports

threads: 4
min_quality: 20

snpeff_db: GRCh38.86
```

---

## Run the Pipeline

Make script executable:

```bash
chmod +x scripts/run_pipeline.sh
```

Run:

```bash
./scripts/run_pipeline.sh
```

---

## Input

```text
Paired-end FASTQ files (.fastq.gz)
Reference genome (.fa)
```

---

## Output

```text
results/qc/           → FastQC reports
results/alignment/    → BAM files
results/variants/     → VCF files
results/annotation/   → Annotated variants
results/reports/      → Summary files
```

---

---

## Features

- Automated end-to-end workflow  
- Config-driven execution  
- Structured outputs  
- Logging support  
- Real-world dataset  

---

## Limitations

- Low-coverage WGS data may affect accuracy  
- Single sample analysis  
- Limited annotation scope  

---

## Future Improvements

- Snakemake / Nextflow integration  
- Multi-sample support  
- Docker containerization  
- MultiQC reporting  

---

## Author

Bushra Rahman
