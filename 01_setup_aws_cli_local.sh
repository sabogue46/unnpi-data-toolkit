#!/bin/bash
# ============================================================
# STEP 1: Install and Configure AWS CLI (Local/GFE Edition)
# ============================================================
# Run locally on GFE machine
# You'll need the IAM access keys from DoD SAFE
# ============================================================

echo "============================================"
echo "  AWS CLI Setup for UNNPI S3 Bucket Access"
echo "  (Local/GFE Edition)"
echo "============================================"
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
else
    OS="unknown"
fi

echo "Detected OS: ${OS}"
echo ""

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
    echo "[OK] AWS CLI is already installed: $(aws --version)"
else
    echo "[INFO] AWS CLI not found. Installing..."
    echo ""

    case $OS in
        linux)
            # Linux installation
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf awscliv2.zip aws/
            ;;
        macos)
            # macOS installation
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
            ;;
        windows)
            # Windows installation
            echo "Please download and install AWS CLI from:"
            echo "https://awscli.amazonaws.com/AWSCLIV2.msi"
            echo ""
            echo "After installation, run this script again."
            exit 0
            ;;
        *)
            echo "[ERROR] Unsupported OS. Please install AWS CLI manually."
            exit 1
            ;;
    esac

    echo "[OK] AWS CLI installed"
fi

echo ""
echo "============================================"
echo "  AWS CLI Configuration"
echo "============================================"
echo ""

# Check if unnpi profile already exists
if aws configure list --profile unnpi &> /dev/null; then
    echo "[OK] AWS profile 'unnpi' already configured"
    echo "Testing connection..."
    if aws sts get-caller-identity --profile unnpi &> /dev/null; then
        echo "[OK] Profile 'unnpi' is working"
    else
        echo "[ERROR] Profile 'unnpi' exists but credentials are invalid"
        echo "Please reconfigure with correct credentials from DoD SAFE"
        aws configure --profile unnpi
    fi
else
    echo "[INFO] Configuring AWS profile 'unnpi' for GovCloud access"
    echo ""
    echo "You'll need your IAM access keys from DoD SAFE:"
    echo "- AWS Access Key ID"
    echo "- AWS Secret Access Key"
    echo ""
    aws configure --profile unnpi
fi

echo ""
echo "============================================"
echo "  Testing GovCloud Access"
echo "============================================"

# Test access to the UNNPI bucket
BUCKET="${UNNPI_S3_BUCKET:?Set UNNPI_S3_BUCKET first (copy config.example.sh -> config.sh and 'source ./config.sh')}"
REGION="${UNNPI_AWS_REGION:-us-gov-west-1}"

echo "Testing access to s3://${BUCKET}..."
if aws s3 ls "s3://${BUCKET}/" --profile unnpi --region "${REGION}" &> /dev/null; then
    echo "[OK] Successfully connected to UNNPI S3 bucket"
    echo "[OK] GovCloud access confirmed"
else
    echo "[ERROR] Cannot access UNNPI S3 bucket"
    echo "Please check:"
    echo "1. Your IAM credentials are correct"
    echo "2. You have permission to access the UNNPI S3 bucket"
    echo "3. You're using the correct GovCloud region (us-gov-west-1)"
    exit 1
fi

echo ""
echo "Setup complete! You can now run Step 2 to download data."
echo ""
echo "Usage: aws s3 ls s3://${BUCKET}/ --profile unnpi --region ${REGION}"