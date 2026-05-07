# UNNPI Data Toolkit
## S3 Download + PostgreSQL Import for JEDMICS & CDMD-OA Data

This toolkit provides scripts for downloading UNNPI database dumps from the GovCloud S3 bucket and importing them into PostgreSQL. Available in two editions:

- **AWS Workspace Edition** (PowerShell scripts for Windows Workspaces)
- **CloudShell Edition** (Bash scripts for AWS CloudShell)

## Prerequisites

### AWS Workspace Edition
- AWS Workspace with network access to GovCloud
- Python 3.8+ (usually pre-installed on Workspaces)
- IAM access keys for the `nnpi-mbps` user (sent via DoD SAFE)

### CloudShell Edition
- AWS CloudShell access (pre-authenticated with your AWS account)
- Python 3.x (pre-installed in CloudShell)

## Quick Start

### AWS Workspace Edition (Windows PowerShell)

#### Step 1: Install & Configure AWS CLI
```powershell
.\01_setup_aws_cli.ps1
```
Sets up AWS CLI with a dedicated `unnpi` profile for the GovCloud bucket.

#### Step 2: Download Data from S3
```powershell
.\02_download_s3_data.ps1              # download everything
.\02_download_s3_data.ps1 -ListOnly    # just see what's there first
```
Downloads to `%USERPROFILE%\UNNPI_Data` by default.

#### Step 3: Install PostgreSQL and Set Up Database
```powershell
.\03_setup_postgresql.ps1
```

#### Step 4: Import Data into PostgreSQL
```powershell
pip install psycopg2-binary
python 04_import_to_postgres.py
```

#### Step 5: Run Queries / Get Data Counts
```powershell
python 05_query_data.py
```

### CloudShell Edition (AWS CloudShell)

#### Step 1: Verify AWS CLI Setup
```bash
chmod +x 01_setup_aws_cli_cloudshell.sh
./01_setup_aws_cli_cloudshell.sh
```
AWS CLI is pre-installed and authenticated in CloudShell.

#### Step 2: Download Data from S3
```bash
chmod +x 02_download_s3_data_cloudshell.sh
./02_download_s3_data_cloudshell.sh
```
Downloads to `~/UNNPI_Data`.

#### Step 3: Install PostgreSQL and Set Up Database
```bash
chmod +x 03_setup_postgresql_cloudshell.sh
./03_setup_postgresql_cloudshell.sh
```
Installs PostgreSQL on the CloudShell instance.

#### Step 4: Import Data into PostgreSQL
```bash
pip install psycopg2-binary
python 04_import_to_postgres.py --data-dir ~/UNNPI_Data --db unnpi_jedmics --host localhost --user postgres --password postgres
```

#### Step 5: Run Queries / Get Data Counts
```bash
python 05_query_data.py --db unnpi_jedmics --host localhost --user postgres --password postgres
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
