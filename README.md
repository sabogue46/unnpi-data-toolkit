# UNNPI Data Toolkit
## S3 Download + PostgreSQL Import for JEDMICS & CDMD-OA Data

This toolkit provides scripts for downloading UNNPI database dumps from the GovCloud S3 bucket and importing them into PostgreSQL. Available in multiple editions:

- **AWS Workspace Edition** (PowerShell scripts for Windows Workspaces)
- **CloudShell Edition** (Bash scripts for AWS CloudShell)
- **Local/GFE Edition** (Cross-platform scripts for local machines)

## Prerequisites

### AWS Workspace Edition
- AWS Workspace with network access to GovCloud
- Python 3.8+ (usually pre-installed on Workspaces)
- IAM access keys for the UNNPI S3 user (sent via DoD SAFE)

### CloudShell Edition
- AWS CloudShell access (pre-authenticated with your AWS account)
- Python 3.x (pre-installed in CloudShell)

### Local/GFE Edition
- Local machine with internet access to GovCloud
- Python 3.8+ installed
- IAM access keys for the UNNPI S3 user (sent via DoD SAFE)
- Sufficient local storage for data files

## Configuration (do this first)

The S3 bucket name is **not** hard-coded — you provide it via a local, git-ignored
config file so it never gets committed to a public repo.

**Windows / PowerShell:**
```powershell
Copy-Item config.example.ps1 config.ps1   # then edit config.ps1 with the real bucket name
. .\config.ps1                            # dot-source it in each new shell
```

**Bash (Local/GFE or CloudShell):**
```bash
cp config.example.sh config.sh            # then edit config.sh with the real bucket name
source ./config.sh                        # source it in each new shell
```

The scripts read `UNNPI_S3_BUCKET` (and optionally `UNNPI_AWS_REGION`,
`UNNPI_AWS_PROFILE`) from the environment and will stop with a clear error if the
bucket is not set.

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

### Local/GFE Edition (Cross-platform)

#### Step 1: Install & Configure AWS CLI
```bash
chmod +x 01_setup_aws_cli_local.sh
./01_setup_aws_cli_local.sh
```
Installs AWS CLI (if needed) and configures the `unnpi` profile for GovCloud access.

#### Step 2: Download Data from S3
```bash
chmod +x 02_download_s3_data_local.sh
./02_download_s3_data_local.sh
```
Downloads to `~/UNNPI_Data` with options for full download or specific files.

#### Step 3: Install PostgreSQL Locally
**Windows:**
- Download PostgreSQL from: https://www.postgresql.org/download/windows/
- Install with default settings

**macOS:**
```bash
brew install postgresql
brew services start postgresql
```

**Linux:**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

#### Step 4: Import Data into PostgreSQL
```bash
pip install psycopg2-binary
python 04_import_to_postgres.py --data-dir ~/UNNPI_Data
```

#### Step 5: Run Queries / Get Data Counts
```bash
python 05_query_data.py
```

### CloudShell Edition (AWS CloudShell)

**⚠️ Storage Warning:** CloudShell has limited storage (~1GB). The UNNPI data files may be large. Consider using an EC2 instance for full processing.

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
**Options due to storage limits:**
- Download specific files only
- Download to another S3 bucket (recommended)
- Use EC2 instance with larger storage

#### Step 3: Install PostgreSQL and Set Up Database
```bash
chmod +x 03_setup_postgresql_cloudshell.sh
./03_setup_postgresql_cloudshell.sh
```
Installs PostgreSQL on the CloudShell instance (may not persist).

#### Step 4: Import Data into PostgreSQL
```bash
pip install psycopg2-binary
python 04_import_to_postgres.py --data-dir ~/UNNPI_Data --db unnpi_jedmics --host localhost --user postgres --password postgres
```

#### Step 5: Run Queries / Get Data Counts
```bash
python 05_query_data.py --db unnpi_jedmics --host localhost --user postgres --password postgres
```

### Alternative: Use EC2 Instance (Recommended for Large Datasets)

For processing large UNNPI datasets, launch an EC2 instance in GovCloud:

#### Find Correct AMI ID in GovCloud:
```bash
# In CloudShell, find Amazon Linux 2 AMI ID for us-gov-west-1
aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" --region us-gov-west-1 --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text
```

#### Launch EC2 Instance:
1. **Region**: us-gov-west-1 (GovCloud)
2. **AMI**: Use the ID from the command above (Amazon Linux 2)
3. **Instance Type**: t3.medium or larger
4. **Storage**: 50GB+ EBS volume (gp3 recommended)
5. **Security Group**: Allow SSH (port 22) from your IP
6. **Key Pair**: Create or use existing key pair

#### Connect and Setup:
```bash
# SSH to your instance
ssh -i your-key.pem ec2-user@your-instance-ip

# Update system and install dependencies
sudo yum update -y
sudo yum install -y git postgresql postgresql-server postgresql-devel python3-pip

# Clone toolkit
git clone https://github.com/sabogue46/unnpi-data-toolkit.git
cd unnpi-data-toolkit

# Run the toolkit
chmod +x *.sh
./01_setup_aws_cli_cloudshell.sh
./02_download_s3_data_cloudshell.sh
./03_setup_postgresql_cloudshell.sh
pip3 install psycopg2-binary
python3 04_import_to_postgres.py
python3 05_query_data.py
```

#### Alternative: Use AWS Console
1. Go to EC2 Console in us-gov-west-1
2. Click "Launch Instance"
3. Search for "Amazon Linux 2" in the AMI catalog
4. Complete the instance configuration as above

## S3 Bucket Structure
```
s3://<your-bucket-name>/        (us-gov-west-1)
├── NNSY_20260311/           # Norfolk JEDMICS (Rehearsal 1 cut, uploaded 3/17)
├── NNSY/                    # Norfolk JEDMICS (older)
├── test/                    # Puget Sound JEDMICS
└── [other folders]
```

## Key Contacts

> Contact names, emails, and phone numbers are **not stored in this repository**.
> Keep the point-of-contact list in an internal, non-public location (e.g. a
> git-ignored `CONTACTS.md`, SharePoint, or your team wiki).

Roles to track internally:
- **S3 Access / IAM** — bucket access and IAM key issues
- **NNSY JEDMICS** — Norfolk source data
- **PSNS JEDMICS** — Puget Sound source data
- **CDMD-OA** — CDMD-OA data (delivered via DoD SAFE)
- **Beast Code (S3 / Cyber)** — bucket/cyber coordination
- **Beast Code (Dev / CSV exports)** — CSV export requests
