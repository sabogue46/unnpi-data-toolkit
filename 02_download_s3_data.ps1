# ============================================================
# STEP 2: Download UNNPI Data from S3 Bucket
# ============================================================
# Downloads JEDMICS dumps from NNSY and PSNS
# Run in PowerShell on your AWS Workspace
# Uses the 'unnpi' AWS profile created in Step 1
# ============================================================

param(
    [string]$DownloadPath = "$env:USERPROFILE\UNNPI_Data",
    [string]$Bucket = $(if ($env:UNNPI_S3_BUCKET) { $env:UNNPI_S3_BUCKET } else { "" }),
    [string]$Region = $(if ($env:UNNPI_AWS_REGION) { $env:UNNPI_AWS_REGION } else { "us-gov-west-1" }),
    [string]$Profile = $(if ($env:UNNPI_AWS_PROFILE) { $env:UNNPI_AWS_PROFILE } else { "unnpi" }),
    [switch]$ListOnly  # Just list contents without downloading
)

if (-not $Bucket) {
    Write-Host "[ERROR] S3 bucket not set. Copy config.example.ps1 -> config.ps1, fill it in," -ForegroundColor Red
    Write-Host "        then dot-source it ('. .\config.ps1') or pass -Bucket <name>." -ForegroundColor Red
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  UNNPI S3 Data Download" -ForegroundColor Cyan
Write-Host "  (AWS Workspace Edition)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bucket:    s3://$Bucket" -ForegroundColor Yellow
Write-Host "Profile:   $Profile" -ForegroundColor Yellow
Write-Host "Download:  $DownloadPath" -ForegroundColor Yellow
Write-Host ""

# --- Verify AWS CLI works ---
try {
    aws --version | Out-Null
} catch {
    Write-Host "[ERROR] AWS CLI not found. Run 01_setup_aws_cli.ps1 first." -ForegroundColor Red
    exit 1
}

# --- Verify profile exists ---
$profileTest = aws configure list --profile $Profile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] AWS profile '$Profile' not found. Run 01_setup_aws_cli.ps1 first." -ForegroundColor Red
    exit 1
}

# --- Check disk space ---
$drive = (Split-Path $DownloadPath -Qualifier)
if ($drive) {
    $disk = Get-PSDrive ($drive -replace ":", "")
    $freeGB = [math]::Round($disk.Free / 1GB, 1)
    Write-Host "Free disk space on $drive : $freeGB GB" -ForegroundColor Yellow
    if ($freeGB -lt 10) {
        Write-Host "[WARNING] Low disk space. JEDMICS dumps can be large." -ForegroundColor Red
        Write-Host "Consider using a different drive or cleaning up space." -ForegroundColor Red
    }
}
Write-Host ""

# --- List bucket contents ---
Write-Host "Listing S3 bucket contents..." -ForegroundColor Yellow
Write-Host ""

$folders = @(
    "NNSY_20260311",   # Latest NNSY JEDMICS (Rehearsal 1 cut, uploaded 3/17/2026)
    "NNSY",            # Older NNSY JEDMICS
    "test"             # PSNS JEDMICS (Puget Sound)
)

foreach ($folder in $folders) {
    Write-Host "--- s3://$Bucket/$folder/ ---" -ForegroundColor Cyan
    $listing = aws s3 ls "s3://$Bucket/$folder/" --human-readable --profile $Profile --region $Region 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $listing
    } else {
        Write-Host "  [SKIP] Could not list folder (may not exist or no access)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Also list root to catch any other folders
Write-Host "--- s3://$Bucket/ (root) ---" -ForegroundColor Cyan
aws s3 ls "s3://$Bucket/" --profile $Profile --region $Region 2>&1
Write-Host ""

if ($ListOnly) {
    Write-Host "List-only mode. Exiting." -ForegroundColor Yellow
    Write-Host "To download, run without -ListOnly flag." -ForegroundColor Gray
    exit 0
}

# --- Confirm download ---
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Ready to download. This may take a while depending on file sizes." -ForegroundColor Yellow
Write-Host "Data will be saved to: $DownloadPath" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Proceed with download? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# --- Create download directory ---
if (-not (Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
    Write-Host "[OK] Created directory: $DownloadPath" -ForegroundColor Green
}

# --- Download each folder ---
$startTime = Get-Date

# NNSY Rehearsal 1 (latest, this is the one you want)
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Downloading NNSY JEDMICS (Rehearsal 1 cut)..." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
$nnsyDir = "$DownloadPath\NNSY_20260311"
if (-not (Test-Path $nnsyDir)) { New-Item -ItemType Directory -Path $nnsyDir -Force | Out-Null }

aws s3 sync "s3://$Bucket/NNSY_20260311/" $nnsyDir --profile $Profile --region $Region 2>&1
if ($LASTEXITCODE -eq 0) {
    $nnsySize = (Get-ChildItem $nnsyDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $nnsySizeGB = if ($nnsySize) { [math]::Round($nnsySize/1GB, 2) } else { 0 }
    Write-Host "[OK] NNSY download complete. Size: $nnsySizeGB GB" -ForegroundColor Green
} else {
    Write-Host "[WARNING] NNSY download may have had issues." -ForegroundColor Red
}

# PSNS JEDMICS
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Downloading PSNS JEDMICS..." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
$psnsDir = "$DownloadPath\PSNS"
if (-not (Test-Path $psnsDir)) { New-Item -ItemType Directory -Path $psnsDir -Force | Out-Null }

aws s3 sync "s3://$Bucket/test/" $psnsDir --profile $Profile --region $Region 2>&1
if ($LASTEXITCODE -eq 0) {
    $psnsSize = (Get-ChildItem $psnsDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $psnsSizeGB = if ($psnsSize) { [math]::Round($psnsSize/1GB, 2) } else { 0 }
    Write-Host "[OK] PSNS download complete. Size: $psnsSizeGB GB" -ForegroundColor Green
} else {
    Write-Host "[WARNING] PSNS download may have had issues." -ForegroundColor Red
}

# --- Summary ---
$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Download Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "Time elapsed: $($elapsed.ToString('hh\:mm\:ss'))"
Write-Host ""
Write-Host "Downloaded data:" -ForegroundColor Yellow
Write-Host "  NNSY (Rehearsal 1): $nnsyDir"
Write-Host "  PSNS:               $psnsDir"
Write-Host ""
Write-Host "NOTE: CDMD-OA data comes via DoD SAFE (not S3)." -ForegroundColor Yellow
Write-Host "Check with the CDMD-OA and Beast Code points of contact for that data." -ForegroundColor Yellow
Write-Host ""
Write-Host "Next step: Run 03_setup_postgresql.ps1" -ForegroundColor Cyan

# --- Log the download for reference ---
$logContent = @"
UNNPI Data Download Log
========================
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Bucket: s3://$Bucket
Region: $Region
Profile: $Profile
Machine: $env:COMPUTERNAME (AWS Workspace)

Downloaded:
  NNSY_20260311 -> $nnsyDir
  test (PSNS)   -> $psnsDir

Elapsed: $($elapsed.ToString('hh\:mm\:ss'))
"@
Set-Content -Path "$DownloadPath\download_log.txt" -Value $logContent
Write-Host "Download log saved to: $DownloadPath\download_log.txt" -ForegroundColor Gray
