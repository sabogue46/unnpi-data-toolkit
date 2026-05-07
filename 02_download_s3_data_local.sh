#!/bin/bash
# ============================================================
# STEP 2: Download UNNPI Data from S3 Bucket (Local/GFE Edition)
# ============================================================
# Downloads JEDMICS dumps from NNSY and PSNS
# Run locally on GFE with AWS CLI installed
# ============================================================

DOWNLOAD_PATH="${HOME}/UNNPI_Data"
BUCKET="YOUR-BUCKET-NAME"
REGION="us-gov-west-1"

echo "============================================"
echo "  UNNPI S3 Data Download"
echo "  (Local/GFE Edition)"
echo "============================================"
echo ""
echo "Bucket:    s3://${BUCKET}"
echo "Download:  ${DOWNLOAD_PATH}"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI not found. Please install AWS CLI first:"
    echo "  Windows: https://awscli.amazonaws.com/AWSCLIV2.msi"
    echo "  Linux/macOS: pip install awscli"
    exit 1
fi

# Check AWS credentials
echo "============================================"
echo "  AWS Credentials Check"
echo "============================================"
if ! aws sts get-caller-identity &> /dev/null; then
    echo "[ERROR] AWS credentials not configured or invalid."
    echo "Please configure AWS CLI with GovCloud credentials:"
    echo "  aws configure --profile unnpi"
    echo "  AWS Access Key ID: [from DoD SAFE]"
    echo "  AWS Secret Access Key: [from DoD SAFE]"
    echo "  Default region: us-gov-west-1"
    exit 1
fi

echo "[OK] AWS credentials configured"
echo ""

# Create download directory
mkdir -p "${DOWNLOAD_PATH}"

# Check available disk space
echo "============================================"
echo "  Disk Space Check"
echo "============================================"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    df -h "${HOME}"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    df -h "${HOME}"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    powershell.exe -Command "Get-PSDrive | Where-Object { $_.Name -eq 'C' } | Select-Object Name, @{Name='Used(GB)';Expression={[math]::Round($_.Used/1GB,2)}}, @{Name='Free(GB)';Expression={[math]::Round($_.Free/1GB,2)}}"
else
    echo "Unable to check disk space on this OS"
fi

echo ""
echo "============================================"
echo "  S3 Bucket Contents & Sizes"
echo "============================================"
aws s3 ls "s3://${BUCKET}/" --region "${REGION}" --recursive --summarize | tail -10

echo ""
echo "============================================"
echo "  Download Options"
echo "============================================"
echo "1. Download all files"
echo "2. Download specific files only"
echo "3. List all files first"
echo ""

read -p "Choose option (1/2/3): " choice
echo ""

case $choice in
    1)
        echo "============================================"
        echo "  Downloading ALL files..."
        echo "  This may take a while and use significant disk space"
        echo "============================================"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws s3 cp "s3://${BUCKET}" "${DOWNLOAD_PATH}" --recursive --region "${REGION}"
            echo ""
            echo "[OK] Download complete! Files are in: ${DOWNLOAD_PATH}"
        else
            echo "Download cancelled."
        fi
        ;;
    2)
        echo "Enter the specific file path to download (from S3 listing above):"
        echo "Example: path/to/file.dmp"
        read -p "File path: " file_path
        aws s3 cp "s3://${BUCKET}/${file_path}" "${DOWNLOAD_PATH}/" --region "${REGION}"
        echo "[OK] Downloaded: ${file_path}"
        ;;
    3)
        echo "============================================"
        echo "  Full S3 Bucket Listing"
        echo "============================================"
        aws s3 ls "s3://${BUCKET}/" --region "${REGION}" --recursive
        ;;
    *)
        echo "Invalid option."
        ;;
esac

echo ""
echo "Script complete."