#!/bin/bash
# ============================================================
# STEP 2: Download UNNPI Data from S3 Bucket (CloudShell Edition)
# ============================================================
# Downloads JEDMICS dumps from NNSY and PSNS
# Run in AWS CloudShell
# ============================================================

DOWNLOAD_PATH="${HOME}/UNNPI_Data"
BUCKET="YOUR-BUCKET-NAME"
REGION="us-gov-west-1"

echo "============================================"
echo "  UNNPI S3 Data Download"
echo "  (CloudShell Edition)"
echo "============================================"
echo ""
echo "Bucket:    s3://${BUCKET}"
echo "Download:  ${DOWNLOAD_PATH}"
echo ""

#!/bin/bash
# ============================================================
# STEP 2: Download UNNPI Data from S3 Bucket (CloudShell Edition)
# ============================================================
# Downloads JEDMICS dumps from NNSY and PSNS
# Run in AWS CloudShell
# ============================================================

DOWNLOAD_PATH="${HOME}/UNNPI_Data"
BUCKET="YOUR-BUCKET-NAME"
REGION="us-gov-west-1"

echo "============================================"
echo "  UNNPI S3 Data Download"
echo "  (CloudShell Edition)"
echo "============================================"
echo ""
echo "Bucket:    s3://${BUCKET}"
echo "Download:  ${DOWNLOAD_PATH}"
echo ""

# Check available disk space FIRST
echo "============================================"
echo "  Disk Space Check"
echo "============================================"
df -h "${HOME}"
echo ""

# List bucket contents and sizes
echo "============================================"
echo "  S3 Bucket Contents & Sizes"
echo "============================================"
aws s3 ls "s3://${BUCKET}/" --region "${REGION}" --recursive --summarize | tail -10

echo ""
echo "============================================"
echo "  Download Options (due to limited CloudShell storage)"
echo "============================================"
echo "1. Download specific files only"
echo "2. Download to S3 bucket instead (recommended)"
echo "3. Use EC2 instance with larger storage"
echo ""

read -p "Choose option (1/2/3) or 'list' to see files: " choice
echo ""

case $choice in
    1)
        echo "Enter the specific file path to download (from S3 listing above):"
        read -p "File path: " file_path
        mkdir -p "${DOWNLOAD_PATH}"
        aws s3 cp "s3://${BUCKET}/${file_path}" "${DOWNLOAD_PATH}/" --region "${REGION}"
        ;;
    2)
        echo "Enter your S3 bucket name for storing the data:"
        read -p "Target S3 bucket: " target_bucket
        echo "Downloading to s3://${target_bucket}/UNNPI_Data/ ..."
        aws s3 cp "s3://${BUCKET}" "s3://${target_bucket}/UNNPI_Data/" --recursive --region "${REGION}"
        echo "Data stored in: s3://${target_bucket}/UNNPI_Data/"
        ;;
    3)
        echo "Consider launching an EC2 instance with:"
        echo "- Instance type: t3.medium or larger"
        echo "- Storage: 50GB+ EBS volume"
        echo "- AMI: Amazon Linux 2"
        echo ""
        echo "Then run the toolkit on the EC2 instance."
        ;;
    list)
        echo "============================================"
        echo "  Full S3 Bucket Listing"
        echo "============================================"
        aws s3 ls "s3://${BUCKET}/" --region "${REGION}" --recursive
        ;;
    *)
        echo "Invalid option. Run script again to choose."
        ;;
esac

echo ""
echo "Script complete."