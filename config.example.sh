# config.example.sh
# -----------------------------------------------------------------------------
# Copy this file to "config.sh" (which is git-ignored), fill in the real values,
# then source it before running any toolkit script:
#
#     cp config.example.sh config.sh
#     # edit config.sh with the real bucket name
#     source ./config.sh
#     ./02_download_s3_data_local.sh
#
# Do NOT put the real bucket name / account id in any committed file.
# -----------------------------------------------------------------------------

export UNNPI_S3_BUCKET="your-bucket-name-here"   # provided by your project lead / IAM owner
export UNNPI_AWS_REGION="us-gov-west-1"           # GovCloud region
export UNNPI_AWS_PROFILE="unnpi"                  # local AWS CLI profile name
