# config.example.ps1
# -----------------------------------------------------------------------------
# Copy this file to "config.ps1" (which is git-ignored), fill in the real values,
# then dot-source it before running any toolkit script:
#
#     Copy-Item config.example.ps1 config.ps1
#     # edit config.ps1 with the real bucket name
#     . .\config.ps1
#     .\02_download_s3_data.ps1
#
# Do NOT put the real bucket name / account id in any committed file.
# -----------------------------------------------------------------------------

$env:UNNPI_S3_BUCKET  = "your-bucket-name-here"   # provided by your project lead / IAM owner
$env:UNNPI_AWS_REGION = "us-gov-west-1"           # GovCloud region
$env:UNNPI_AWS_PROFILE = "unnpi"                  # local AWS CLI profile name
