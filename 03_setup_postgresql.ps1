# ============================================================
# STEP 3: Set Up PostgreSQL for UNNPI Data
# ============================================================
# Creates the database and schemas for importing JEDMICS data
# Run in PowerShell on your AWS Workspace
# ============================================================

param(
    [string]$PgHost = "localhost",
    [int]$PgPort = 5432,
    [string]$PgUser = "postgres",
    [string]$DbName = "unnpi_jedmics"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PostgreSQL Setup for UNNPI Data" -ForegroundColor Cyan
Write-Host "  (AWS Workspace Edition)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Check if PostgreSQL is installed ---
$pgInstalled = Get-Command psql -ErrorAction SilentlyContinue
if (-not $pgInstalled) {
    # Check common install locations
    $pgPaths = @(
        "C:\Program Files\PostgreSQL\17\bin",
        "C:\Program Files\PostgreSQL\16\bin",
        "C:\Program Files\PostgreSQL\15\bin",
        "C:\Program Files\PostgreSQL\14\bin"
    )
    foreach ($p in $pgPaths) {
        if (Test-Path "$p\psql.exe") {
            Write-Host "[FOUND] PostgreSQL detected at: $p" -ForegroundColor Green
            $env:Path += ";$p"
            $pgInstalled = $true
            break
        }
    }
}

if (-not $pgInstalled -and -not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO] PostgreSQL not found. Let's install it." -ForegroundColor Yellow
    Write-Host ""

    # Try winget first (no admin needed on most Workspaces)
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetAvailable) {
        Write-Host "Option 1: Install via winget (recommended):" -ForegroundColor Cyan
        Write-Host '  winget install PostgreSQL.PostgreSQL.16' -ForegroundColor White
        Write-Host ""
    }

    Write-Host "Option 2: Download installer:" -ForegroundColor Cyan
    Write-Host "  https://www.postgresql.org/download/windows/" -ForegroundColor White
    Write-Host "  - Use default port 5432" -ForegroundColor Gray
    Write-Host "  - Set a password for the 'postgres' user (remember it!)" -ForegroundColor Gray
    Write-Host "  - The installer should work on AWS Workspace without admin" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Option 3: Use portable/zip PostgreSQL (zero install):" -ForegroundColor Cyan
    Write-Host "  https://www.enterprisedb.com/download-postgresql-binaries" -ForegroundColor White
    Write-Host "  - Download the zip, extract to a folder" -ForegroundColor Gray
    Write-Host "  - No installer or admin rights needed" -ForegroundColor Gray
    Write-Host "  - Run: initdb -D .\data" -ForegroundColor Gray
    Write-Host "  - Run: pg_ctl -D .\data start" -ForegroundColor Gray
    Write-Host ""

    Write-Host "After installing, add PostgreSQL bin to your PATH:" -ForegroundColor Yellow
    Write-Host '  $env:Path += ";C:\Program Files\PostgreSQL\16\bin"' -ForegroundColor White
    Write-Host "Then re-run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] PostgreSQL found: $(psql --version)" -ForegroundColor Green
Write-Host ""

# --- Prompt for password ---
$pgPassword = Read-Host "Enter PostgreSQL password for user '$PgUser'" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pgPassword)
)

# --- Test connection ---
Write-Host "Testing PostgreSQL connection..." -ForegroundColor Yellow
$testResult = psql -h $PgHost -p $PgPort -U $PgUser -d postgres -c "SELECT version();" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Could not connect to PostgreSQL." -ForegroundColor Red
    Write-Host $testResult
    Write-Host ""
    Write-Host "Make sure PostgreSQL is running:" -ForegroundColor Yellow
    Write-Host "  - Check Services (services.msc) for 'postgresql'" -ForegroundColor Gray
    Write-Host "  - Or start manually: pg_ctl -D <datadir> start" -ForegroundColor Gray
    $env:PGPASSWORD = ""
    exit 1
}
Write-Host "[OK] Connected to PostgreSQL." -ForegroundColor Green
Write-Host ""

# --- Create database ---
Write-Host "Creating database '$DbName'..." -ForegroundColor Yellow

$createDbSql = @"
SELECT 'CREATE DATABASE $DbName'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DbName')\gexec
"@

echo $createDbSql | psql -h $PgHost -p $PgPort -U $PgUser -d postgres 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Database '$DbName' ready." -ForegroundColor Green
} else {
    Write-Host "[INFO] Database may already exist, continuing..." -ForegroundColor Yellow
}

# --- Create schemas ---
Write-Host "Creating schemas..." -ForegroundColor Yellow

$schemaSql = @"
-- Schemas for each data source
CREATE SCHEMA IF NOT EXISTS nnsy_jedmics;
CREATE SCHEMA IF NOT EXISTS psns_jedmics;
CREATE SCHEMA IF NOT EXISTS cdmdoa;

-- Extension for fuzzy text matching on drawing numbers
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Metadata tracking table
CREATE TABLE IF NOT EXISTS public.import_log (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL,
    filename VARCHAR(500),
    table_name VARCHAR(200),
    row_count BIGINT,
    imported_at TIMESTAMP DEFAULT NOW(),
    notes TEXT
);

COMMENT ON SCHEMA nnsy_jedmics IS 'Norfolk Naval Shipyard JEDMICS data';
COMMENT ON SCHEMA psns_jedmics IS 'Puget Sound Naval Shipyard JEDMICS data';
COMMENT ON SCHEMA cdmdoa IS 'CDMD-OA configuration data';
"@

echo $schemaSql | psql -h $PgHost -p $PgPort -U $PgUser -d $DbName 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Schemas created (nnsy_jedmics, psns_jedmics, cdmdoa)." -ForegroundColor Green
} else {
    Write-Host "[WARNING] Schema creation had issues. Check output above." -ForegroundColor Red
}

# Clean up
$env:PGPASSWORD = ""

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  PostgreSQL Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Database: $DbName"
Write-Host "Schemas:  nnsy_jedmics, psns_jedmics, cdmdoa"
Write-Host ""
Write-Host "Next step: python 04_import_to_postgres.py --data-dir `"$env:USERPROFILE\UNNPI_Data`"" -ForegroundColor Cyan
