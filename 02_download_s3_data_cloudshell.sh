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

# Create download directory
mkdir -p "${DOWNLOAD_PATH}"

# Check available disk space
echo "Checking disk space..."
df -h "${HOME}"

# List bucket contents first
echo ""
echo "============================================"
echo "  Listing S3 bucket contents..."
echo "============================================"
aws s3 ls "s3://${BUCKET}/" --region "${REGION}"

echo ""
read -p "Do you want to download all files? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled. You can run individual downloads with:"
    echo "aws s3 cp s3://${BUCKET}/path/to/file ${DOWNLOAD_PATH}/ --region ${REGION}"
    exit 0
fi

# Download all files
echo ""
echo "============================================"
echo "  Downloading files..."
echo "============================================"
aws s3 cp "s3://${BUCKET}" "${DOWNLOAD_PATH}" --recursive --region "${REGION}"

echo ""
echo "Download complete! Files are in: ${DOWNLOAD_PATH}"
echo "Proceed to Step 3."