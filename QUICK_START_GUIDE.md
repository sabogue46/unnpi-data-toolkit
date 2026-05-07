# UNNPI Data Toolkit - Complete Step-by-Step Guide

## Overview

This toolkit helps you download UNNPI database dumps from AWS GovCloud S3 and import them into PostgreSQL for analysis. It's designed to work in different environments:

- **CloudShell Edition**: Run directly in AWS CloudShell (easiest if you have CloudShell access)
- **Local/GFE Edition**: Run on your local Windows/Linux/macOS machine
- **AWS Workspace Edition**: Run on Windows AWS Workspaces

---

## Table of Contents

1. [Choose Your Edition](#choose-your-edition)
2. [CloudShell Edition Setup](#cloudshell-edition-setup)
3. [Local/GFE Edition Setup](#localgfe-edition-setup)
4. [Understanding the Data](#understanding-the-data)
5. [Troubleshooting](#troubleshooting)

---

## Choose Your Edition

### CloudShell Edition ✅ RECOMMENDED if you have:
- AWS account with CloudShell access
- Limited local storage (CloudShell has ~1GB)
- Don't want to manage your own database

### Local/GFE Edition ✅ BEST if you have:
- Local machine with 50GB+ free storage
- Want full control over the data
- Already have PostgreSQL or can install it

### AWS Workspace Edition ✅ For AWS Workspaces users:
- Windows PowerShell scripts instead of bash
- Similar steps to Local edition but for Workspaces

---

## CloudShell Edition Setup

### What You Need
- AWS account with GovCloud access
- IAM access keys for the `nnpi-mbps` user (from DoD SAFE)
- Browser with internet access
- About 30 minutes

### What This Does
1. Verifies AWS CLI and credentials in CloudShell
2. Lists what's available in the S3 bucket
3. Options to download files or use another S3 bucket for storage
4. Sets up PostgreSQL on the CloudShell instance
5. Imports and queries the data

### Step 1: Download the Toolkit to CloudShell

```bash
# Option A: Upload ZIP from your computer
# Click "Actions" → "Upload file" in CloudShell
# Select: unnpi-data-toolkit.zip
# Then extract:
unzip unnpi-data-toolkit.zip
cd unnpi-data-toolkit/

# Option B: Download directly from GitHub
wget https://github.com/sabogue46/unnpi-data-toolkit/archive/refs/heads/main.zip
unzip main.zip
cd unnpi-data-toolkit-main/
```

**Why:** You need the scripts and Python files on CloudShell to run them.

---

### Step 2: Verify AWS CLI and Check S3 Bucket

```bash
chmod +x 01_setup_aws_cli_cloudshell.sh
./01_setup_aws_cli_cloudshell.sh
```

**What it does:**
- Confirms AWS CLI is installed (it's pre-installed in CloudShell)
- Shows your current AWS identity and region
- Confirms you can access the GovCloud bucket

**Expected output:**
```
[OK] AWS CLI is available: aws-cli/2.x.x Python/3.x.x
Current AWS identity:
    UserId: AIDAI...
    Account: 123456789012
    Arn: arn:aws:iam::123456789012:user/...
```

**If you see an error:**
- Check that you're logged in to AWS (top-right of CloudShell shows your identity)
- Verify your IAM user has GovCloud permissions

---

### Step 3: Check What's in S3 and Download Data

```bash
chmod +x 02_download_s3_data_cloudshell.sh
./02_download_s3_data_cloudshell.sh
```

**What it does:**
1. Shows how much storage CloudShell has free (~1GB typically)
2. Lists all files in the UNNPI S3 bucket
3. Shows file sizes so you know what you're downloading
4. Gives you 3 options:

   **Option 1: Download specific files only**
   - Good if total bucket size is > your free space
   - Example: `NNSY/jedmics_2024_01.dmp` (single file)

   **Option 2: Copy to your own S3 bucket** ⭐ BEST OPTION
   - Avoids CloudShell storage limits entirely
   - Enter your bucket name when prompted
   - Files go to `s3://your-bucket/UNNPI_Data/`
   - You can download from there later to local machine

   **Option 3: Use EC2 instance**
   - For very large datasets

**Check disk space first:**
```bash
df -h $HOME
```

**Example output:**
```
Available: 72G
Total S3 bucket: 45G
→ You have enough space! Choose Option 1 or 2
```

---

### Step 4: Set Up PostgreSQL in CloudShell

```bash
chmod +x 03_setup_postgresql_cloudshell.sh
./03_setup_postgresql_cloudshell.sh
```

**What it does:**
1. Installs PostgreSQL in CloudShell
2. Creates a database called `unnpi_jedmics`
3. Creates a `postgres` user with default password
4. Tests the connection

**Note:** This installation is temporary. If you close CloudShell for 4+ hours, the instance stops and data may be lost.

**Expected output:**
```
[OK] PostgreSQL installed and started
[OK] Database 'unnpi_jedmics' created
[OK] User 'postgres' configured
PostgreSQL version: 14.x
```

---

### Step 5: Import Data into PostgreSQL

First, install the Python database connector:

```bash
pip install psycopg2-binary
```

**What it does:** Installs the library that lets Python talk to PostgreSQL.

Then scan and import:

```bash
# Option A: If you downloaded files to ~/UNNPI_Data
python 04_import_to_postgres.py \
  --data-dir ~/UNNPI_Data \
  --db unnpi_jedmics \
  --host localhost \
  --user postgres \
  --password postgres

# Option B: Just analyze without importing (if unsure)
python 04_import_to_postgres.py \
  --data-dir ~/UNNPI_Data \
  --db unnpi_jedmics \
  --host localhost \
  --user postgres \
  --password postgres \
  --scan-only
```

**What it does:**
1. Scans all files in `~/UNNPI_Data`
2. Finds `.dmp`, `.csv`, and `.sql` files
3. Analyzes `.dmp` files to find table names
4. Creates PostgreSQL tables for CSV/SQL files
5. Loads data into the database

**If you see `.dmp` file warnings:**
→ Go to [Handling .dmp Files](#handling-dmp-files) section below

---

### Step 6: Query the Data and Get Results

```bash
python 05_query_data.py \
  --db unnpi_jedmics \
  --host localhost \
  --user postgres \
  --password postgres
```

**What it does:**
- Connects to your PostgreSQL database
- Runs standard queries (counts, samples, etc.)
- Shows results in terminal
- Optionally exports to CSV

**Output includes:**
- Number of records by table
- Sample data
- Data quality checks

---

## Local/GFE Edition Setup

### What You Need
- Local Windows/Linux/macOS machine
- 50GB+ free storage (check with: `df -h` on Linux/macOS or `wmic logicaldisk get freespace` on Windows)
- Python 3.8+ installed
- PostgreSQL (we'll help you install if needed)
- IAM access keys for the `nnpi-mbps` user (from DoD SAFE)
- AWS CLI (we'll help you install if needed)
- About 1-2 hours (depending on download speed)

### What This Does
1. Installs AWS CLI if you don't have it
2. Configures AWS credentials for GovCloud
3. Downloads UNNPI files from S3 to your local machine
4. Installs and configures PostgreSQL
5. Imports data into PostgreSQL
6. Runs queries and generates reports

---

### Step 1: Check Your Disk Space

**Windows PowerShell:**
```powershell
Get-PSDrive | Where-Object {$_.Provider -like 'FileSystem'} | Select-Object Name, @{Name='FreeGB';Expression={[math]::Round($_.Free/1GB,2)}}
```

**Linux/macOS terminal:**
```bash
df -h ~
```

**You need at least 50GB free. If you have less:**
- Delete unnecessary files first, or
- Run on a different drive with more space, or
- Use the CloudShell edition instead

---

### Step 2: Install AWS CLI

**Windows:**
1. Download: https://awscli.amazonaws.com/AWSCLIV2.msi
2. Run the installer (click next through everything)
3. Restart your terminal

**macOS:**
```bash
brew install awscli
```

**Linux:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/
```

**Verify it installed:**
```bash
aws --version
```

Should show: `aws-cli/2.x.x Python/3.x.x ...`

---

### Step 3: Configure AWS Credentials

In your terminal:

```bash
aws configure --profile unnpi
```

When prompted, enter:
- **AWS Access Key ID:** [from DoD SAFE email]
- **AWS Secret Access Key:** [from DoD SAFE email]
- **Default region:** `us-gov-west-1`
- **Default output format:** `json` (or press Enter)

**Example:**
```
AWS Access Key ID [None]: AKIAI7EXAMPLE1234567
AWS Secret Access Key [None]: wJalrXUtnFEM2NotReal/ExampleSecretKey
Default region name [None]: us-gov-west-1
Default output format [None]: json
```

**Verify credentials work:**

```bash
aws sts get-caller-identity --profile unnpi
```

Should show your AWS account info (if it works).

---

### Step 4: Run the Local Setup Script

```bash
# On Windows PowerShell:
.\01_setup_aws_cli_local.sh

# On Linux/macOS bash:
./01_setup_aws_cli_local.sh
```

(If bash script doesn't run on Windows, you may need a bash shell like Git Bash or WSL.)

---

### Step 5: Download Files from S3

```bash
chmod +x 02_download_s3_data_local.sh
./02_download_s3_data_local.sh
```

**Menu options:**

1. **Download all files** (if you have 50GB+ free)
   - Takes 30-120 minutes depending on internet speed
   - Downloads to `~/UNNPI_Data/`

2. **Download specific files only** (if limited space)
   - List shows in the script output
   - Copy one file path and paste when prompted
   - Example: `NNSY/jedmics_2024_01.dmp`

3. **List all files first** (to see what's available)
   - Doesn't download anything
   - Just shows sizes and names

**Watching progress:**
- The download shows percentage as it goes
- If it gets stuck for 5+ min, press Ctrl+C and try again

---

### Step 6: Install PostgreSQL

**Windows:**
1. Download: https://www.postgresql.org/download/windows/
2. Run installer
3. Keep default settings (port 5432, user: postgres)
4. When asked for password, use: `postgres` (or whatever you want—remember it!)

**macOS:**
```bash
brew install postgresql
brew services start postgresql
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

**Verify it's running:**
```bash
psql --version
```

Should show: `psql (PostgreSQL) 14.x ...` or similar

---

### Step 7: Import Data into PostgreSQL

First install the Python database library:

```bash
pip install psycopg2-binary
```

Then scan the downloaded files:

```bash
python 04_import_to_postgres.py --data-dir ~/UNNPI_Data --scan-only
```

**What this does:**
- Analyzes what files you have
- Identifies Oracle `.dmp` files, CSV files, SQL files
- Shows what tables would be created
- Suggests conversion steps if needed

**Then import (if you have CSV/SQL files):**

```bash
python 04_import_to_postgres.py --data-dir ~/UNNPI_Data --db unnpi_jedmics --user postgres --password postgres
```

**If you get `.dmp` file warnings:**
→ See [Handling .dmp Files](#handling-dmp-files) below

---

### Step 8: Query the Data

```bash
python 05_query_data.py --db unnpi_jedmics --user postgres --password postgres
```

This will:
- Show record counts
- Display sample data
- Run quality checks
- Optionally export to CSV files

---

## Understanding the Data

### What's in the UNNPI S3 Bucket?

The bucket contains Oracle Data Pump files (`.dmp` format) from two sources:

- **NNSY/** - Naval Submarine Base Bangor data (~20GB)
- **PSNS/** - Puget Sound Naval Shipyard data (~15GB)

Each `.dmp` file contains:
- JEDMICS drawing metadata
- Document relationships
- Revision history
- Part lists

### File Formats

| Format | Example | What to Do |
|--------|---------|-----------|
| `.dmp` | `jedmics_2024.dmp` | Oracle dump (needs conversion—see below) |
| `.csv` | `drawings.csv` | Can import directly |
| `.sql` | `schema.sql` | Can execute directly |

---

## Handling .dmp Files

### What's a .dmp File?

A `.dmp` file is an Oracle Data Pump export—a binary backup of an Oracle database. PostgreSQL can't read it directly.

### Your Options (Ranked by Ease)

#### Option 1: Get CSV Files from Oracle Team ⭐ EASIEST

Contact:
- REDACTED (Beast Code)
- REDACTED

Ask for: CSV exports of all JEDMICS tables with headers

**Why:** CSV imports directly, no conversion needed.

**Time:** Ask them—usually turnaround is 1-3 days

---

#### Option 2: Use ora2pg Tool

- Converts Oracle format → PostgreSQL format
- Requires Oracle XE (free) installed first

**Install steps:**

```bash
# Install Oracle XE (free download)
# https://www.oracle.com/database/technologies/xe-downloads.html
# [Follow Oracle's installation instructions]

# Install ora2pg
# On Linux/macOS:
sudo cpan install DBD::Oracle

# On Windows:
perl -MCPAN -e install DBD::Oracle
```

**Then convert:**

```bash
ora2pg -t TABLE -d yourdb -u oracle_user -w oracle_password -P 5432 -b /output/dir/
```

**Turnaround:** 2-4 hours to set up, then automatic conversion

---

#### Option 3: Oracle XE + Manual Export

1. Install Oracle XE (free)
2. Import `.dmp`: 
   ```bash
   impdp system/password dumpfile=jedmics.dmp
   ```
3. Export to CSV in SQL Developer or sqlplus
4. Run the import script again

**Turnaround:** 4-8 hours

---

#### Option 4: Skip PostgreSQL, Use Oracle Directly

If you have Oracle XE running with the data imported:

```bash
# Install Python Oracle driver
pip install oracledb

# Modify 05_query_data.py to connect to Oracle instead
```

**Turnaround:** Same as Option 3, but simpler if you only need queries

---

## Troubleshooting

### "No space left on device"

**In CloudShell:**
- CloudShell has only ~1GB storage—use Option 2 (download to your S3 bucket)

**Locally:**
- Check free space: `df -h ~`
- Delete unnecessary files
- Download to a different drive with more space

---

### "AWS credentials not configured" or "Repository not found"

**Fix:**
1. Verify credentials: `aws sts get-caller-identity --profile unnpi`
2. If error: Run again: `aws configure --profile unnpi`
3. Double-check: Access Key and Secret Key from DoD SAFE email

---

### "Cannot connect to PostgreSQL"

**Check if PostgreSQL is running:**

**Windows:**
```powershell
Get-Service postgresql
# Should show "Running"
```

**macOS:**
```bash
brew services list
# Should show postgresql: started
```

**Linux:**
```bash
sudo systemctl status postgresql
# Should show "active (running)"
```

**If not running, start it:**
- Windows: Services → PostgreSQL → Start
- macOS: `brew services start postgresql`
- Linux: `sudo systemctl start postgresql`

---

### "psycopg2 not found"

```bash
pip install psycopg2-binary
```

---

### ".dmp file detected - cannot import directly"

This is expected. Follow "Handling .dmp Files" section above. Most likely option: ask REDACTED for CSV exports.

---

### "Permission denied" on bash scripts

```bash
chmod +x *.sh
```

Then try running again.

---

## Next Steps

Once you have data in PostgreSQL:

### Run Queries

```bash
python 05_query_data.py
```

Gets you:
- Total drawing counts
- Records per source (NNSY vs PSNS)
- Data quality metrics
- Sample records

### Export Results

```bash
python 05_query_data.py --export-csv
```

Saves results to CSV files you can open in Excel.

### Custom Queries

Connect directly to PostgreSQL:

**Command line:**
```bash
psql -U postgres -d unnpi_jedmics
# Then type SQL: SELECT * FROM public.drawing_metadata LIMIT 10;
```

**From Python:**
```python
import psycopg2

conn = psycopg2.connect("dbname=unnpi_jedmics user=postgres password=postgres")
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM public.drawing_metadata")
print(cur.fetchone())
```

---

## Questions?

Refer to: [GitHub Repository](https://github.com/sabogue46/unnpi-data-toolkit)

For urgent issues: Check toolkit README.md for contact info.

---

## Glossary

| Term | Meaning |
|------|---------|
| S3 | Amazon's file storage service |
| .dmp | Oracle Data Pump backup format |
| PostgreSQL | Open-source SQL database |
| CSV | Plain text file with comma-separated values |
| GovCloud | AWS region for US government (us-gov-west-1) |
| IAM | AWS Identity & Access Management |
| CloudShell | Browser-based terminal in AWS Console |
| psycopg2 | Python library to talk to PostgreSQL |

