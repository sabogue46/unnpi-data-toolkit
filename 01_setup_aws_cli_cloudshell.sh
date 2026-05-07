#!/bin/bash
# ============================================================
# STEP 1: AWS CLI Setup for GovCloud S3 Access (CloudShell Edition)
# ============================================================
# Run this script in AWS CloudShell
# AWS CLI is pre-installed and authenticated
# ============================================================

echo "============================================"
echo "  AWS CLI Setup for UNNPI S3 Bucket Access"
echo "  (CloudShell Edition)"
echo "============================================"
echo ""

# Check if AWS CLI is available (should be pre-installed in CloudShell)
if command -v aws &> /dev/null; then
    echo "[OK] AWS CLI is available: $(aws --version)"
    echo "     (CloudShell has this pre-installed and authenticated)"
else
    echo "[ERROR] AWS CLI not found. This shouldn't happen in CloudShell."
    exit 1
fi

echo ""
echo "============================================"
echo "  AWS CLI Configuration Check"
echo "============================================"
echo ""

# Check current identity
echo "Current AWS identity:"
aws sts get-caller-identity

echo ""
echo "Default region:"
aws configure get region

echo ""
echo "[INFO] If you need to access GovCloud, ensure you're in the correct region (us-gov-west-1)"
echo "[INFO] CloudShell is already authenticated with your AWS account"
echo ""
echo "Setup complete! Proceed to Step 2."