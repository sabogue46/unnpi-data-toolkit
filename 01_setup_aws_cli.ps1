# ============================================================
# STEP 1: Install and Configure AWS CLI for GovCloud S3 Access
# ============================================================
# Run this script in PowerShell on your AWS Workspace
# You'll need the IAM access keys from DoD SAFE
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  AWS CLI Setup for UNNPI S3 Bucket Access" -ForegroundColor Cyan
Write-Host "  (AWS Workspace Edition)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Check if AWS CLI is already installed (common on Workspaces) ---
$awsInstalled = Get-Command aws -ErrorAction SilentlyContinue
if ($awsInstalled) {
    Write-Host "[OK] AWS CLI is already installed: $(aws --version)" -ForegroundColor Green
    Write-Host "     (AWS Workspaces often have this pre-installed)" -ForegroundColor Gray
} else {
    Write-Host "[INFO] AWS CLI not found. Installing..." -ForegroundColor Yellow
    Write-Host ""

    # Method 1: Try winget (available on newer Workspaces)
    $wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetAvailable) {
        Write-Host "Installing via winget..." -ForegroundColor Yellow
        winget install Amazon.AWSCLI --accept-package-agreements --accept-source-agreements 2>&1
    }

    # Refresh PATH and check again
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $awsCheck = Get-Command aws -ErrorAction SilentlyContinue

    if (-not $awsCheck) {
        # Method 2: MSI installer (no admin needed on most Workspaces)
        Write-Host "Trying MSI installer..." -ForegroundColor Yellow
        $installerUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
        $installerPath = "$env:TEMP\AWSCLIV2.msi"

        Write-Host "Downloading AWS CLI installer..."
        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
            Write-Host "Running installer..."
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet" -Wait -NoNewWindow
        } catch {
            Write-Host "[INFO] Web download failed. Trying per-user install..." -ForegroundColor Yellow
            # Method 3: Per-user install (no admin rights needed)
            try {
                Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet INSTALLDIR=`"$env:LOCALAPPDATA\Amazon\AWSCLI`"" -Wait -NoNewWindow
                $env:Path += ";$env:LOCALAPPDATA\Amazon\AWSCLI"
            } catch {
                Write-Host "[ERROR] Could not install AWS CLI automatically." -ForegroundColor Red
                Write-Host ""
                Write-Host "Manual install options:" -ForegroundColor Yellow
                Write-Host "  1. Download from: https://awscli.amazonaws.com/AWSCLIV2.msi"
                Write-Host "  2. Or use pip:  pip install awscli --user"
                Write-Host "  3. Then re-run this script"
                exit 1
            }
        }

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    # Final check
    $awsCheck = Get-Command aws -ErrorAction SilentlyContinue
    if ($awsCheck) {
        Write-Host "[OK] AWS CLI installed successfully: $(aws --version)" -ForegroundColor Green
    } else {
        # Last resort: pip install
        Write-Host "[INFO] Trying pip install as fallback..." -ForegroundColor Yellow
        pip install awscli --user 2>&1
        $env:Path += ";$env:APPDATA\Python\Scripts"
        $awsCheck = Get-Command aws -ErrorAction SilentlyContinue
        if ($awsCheck) {
            Write-Host "[OK] AWS CLI installed via pip: $(aws --version)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Could not install AWS CLI. See manual steps above." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Configure AWS Credentials" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Your Workspace may already have AWS credentials" -ForegroundColor Yellow
Write-Host "configured for its own account. We need to set up a SEPARATE" -ForegroundColor Yellow
Write-Host "profile for the UNNPI GovCloud bucket." -ForegroundColor Yellow
Write-Host ""
$bucket = if ($env:UNNPI_S3_BUCKET) { $env:UNNPI_S3_BUCKET } else { "" }
if (-not $bucket) {
    Write-Host "[ERROR] S3 bucket not set. Copy config.example.ps1 -> config.ps1, fill it in," -ForegroundColor Red
    Write-Host "        then dot-source it ('. .\config.ps1') before running this script." -ForegroundColor Red
    exit 1
}
Write-Host "IAM user: (your UNNPI IAM user)" -ForegroundColor Yellow
Write-Host "S3 bucket: s3://$bucket" -ForegroundColor Yellow
Write-Host "Region: us-gov-west-1 (GovCloud)" -ForegroundColor Yellow
Write-Host ""

# Prompt for credentials
$accessKey = Read-Host "Enter your AWS Access Key ID"
$secretKey = Read-Host "Enter your AWS Secret Access Key" -AsSecureString
$secretKeyPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKey)
)

# Create AWS credentials directory
$awsDir = "$env:USERPROFILE\.aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir | Out-Null
}

# Use a named profile so we don't clobber existing Workspace credentials
$profileName = "unnpi"

# Append/update profile in credentials file
$credFile = "$awsDir\credentials"
$configFile = "$awsDir\config"

# Check if profile already exists
$existingCreds = ""
if (Test-Path $credFile) {
    $existingCreds = Get-Content $credFile -Raw
}

if ($existingCreds -match "\[$profileName\]") {
    Write-Host "[INFO] Updating existing '$profileName' profile..." -ForegroundColor Yellow
    # Replace existing profile block
    $existingCreds = $existingCreds -replace "(?s)\[$profileName\].*?(?=\[|\z)", ""
}

$credBlock = @"

[$profileName]
aws_access_key_id = $accessKey
aws_secret_access_key = $secretKeyPlain
"@
Add-Content -Path $credFile -Value $credBlock

# Same for config file
$existingConfig = ""
if (Test-Path $configFile) {
    $existingConfig = Get-Content $configFile -Raw
}

if ($existingConfig -match "\[profile $profileName\]") {
    $existingConfig = $existingConfig -replace "(?s)\[profile $profileName\].*?(?=\[|\z)", ""
}

$configBlock = @"

[profile $profileName]
region = us-gov-west-1
output = json
"@
Add-Content -Path $configFile -Value $configBlock

Write-Host ""
Write-Host "[OK] AWS credentials configured under profile '$profileName'" -ForegroundColor Green
Write-Host "     All toolkit scripts will use --profile $profileName" -ForegroundColor Gray

# Test connection
Write-Host ""
Write-Host "Testing S3 connection..." -ForegroundColor Yellow
try {
    $result = aws s3 ls "s3://$bucket/" --profile $profileName --region us-gov-west-1 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Successfully connected to S3 bucket!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Bucket contents:" -ForegroundColor Cyan
        Write-Host $result
    } else {
        Write-Host "[WARNING] Could not list bucket. Error:" -ForegroundColor Red
        Write-Host $result
        Write-Host ""
        Write-Host "Common fixes:" -ForegroundColor Yellow
        Write-Host "  - Check that your access keys are correct"
        Write-Host "  - Your Workspace may need network route to GovCloud"
        Write-Host "  - Contact your S3/IAM point of contact if IAM keys have expired"
    }
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Setup complete. Run 02_download_s3_data.ps1 next." -ForegroundColor Cyan
Write-Host "All scripts use: --profile unnpi" -ForegroundColor Gray
