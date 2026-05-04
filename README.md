# UNNPI Data Toolkit (AWS Workspace Edition)
## S3 Download + PostgreSQL Import for JEDMICS & CDMD-OA Data

This toolkit runs on your **AWS Workspace** to download UNNPI database dumps from the GovCloud S3 bucket and import them into a local PostgreSQL database. No GFE admin rights needed.

## Prerequisites
- AWS Workspace with network access to GovCloud
- Python 3.8+ (usually pre-installed on Workspaces)
- IAM access keys for the `nnpi-mbps` user (sent via DoD SAFE)

## Quick Start

### Step 1: Install & Configure AWS CLI
```powershell
.\01_setup_aws_cli.ps1
```
Sets up AWS CLI with a dedicated `unnpi` profile for the GovCloud bucket. Won't interfere with your Workspace's existing AWS credentials.

### Step 2: Download Data from S3
```powershell
.\02_download_s3_data.ps1              # download everything
.\02_download_s3_data.ps1 -ListOnly    # just see what's there first
```
Downloads to `%USERPROFILE%\UNNPI_Data` by default. Check disk space first — JEDMICS dumps can be large.

### Step 3: Install PostgreSQL and Set Up Database
```powershell
.\03_setup_postgresql.ps1
```
If PostgreSQL isn't installed, the script gives you 3 options including a portable/zip install that needs zero admin rights.

### Step 4: Import Data into PostgreSQL
```powershell
pip install psycopg2-binary
python 04_import_to_postgres.py
python 04_import_to_postgres.py --scan-only    # just analyze files without importing
```
Handles CSV/SQL files directly. For Oracle .dmp files, see the conversion guide the script prints.

### Step 5: Run Queries / Get Data Counts
```powershell
python 05_query_data.py                           # run all reports
python 05_query_data.py --report collision         # just collision analysis
python 05_query_data.py --report counts            # just drawing counts
python 05_query_data.py --export-csv               # save results as CSVs for Ely
```

## S3 Bucket Structure
```
s3://YOUR-BUCKET-NAME/        (us-gov-west-1)
├── NNSY_20260311/           # Norfolk JEDMICS (Rehearsal 1 cut, uploaded 3/17)
├── NNSY/                    # Norfolk JEDMICS (older)
├── test/                    # Puget Sound JEDMICS
└── [other folders]
```

## Key Contacts
- **S3 Access/IAM**: REDACTED (REDACTED)
- **NNSY JEDMICS**: REDACTED (REDACTED, REDACTED)
- **PSNS JEDMICS**: REDACTED (REDACTED, REDACTED)
- **CDMD-OA**: REDACTED (REDACTED)
- **Beast Code S3/Cyber**: REDACTED (REDACTED)
- **Beast Code Dev (CSV exports)**: REDACTED
