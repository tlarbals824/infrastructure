# =============================================================================
# Terraform Backend Configuration (OCI Object Storage)
# =============================================================================
# 상태 파일을 OCI Object Storage에 저장하여 팀 협업 및 CI/CD 지원
#
# 사전 준비:
# 1. OCI Object Storage Bucket 생성
# 2. 아래 값을 실제 환경에 맞게 수정

terraform {
  backend "s3" {
    bucket                      = "terraform-state"
    key                         = "terraform.tfstate"
    region                      = "ap-seoul-1"
    endpoint                    = "https://<namespace>.compat.objectstorage.ap-seoul-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    # S3 호환 인증을 위해 AWS 환경변수 사용:
    # AWS_ACCESS_KEY_ID = OCI Customer Secret Key Access Key
    # AWS_SECRET_ACCESS_KEY = OCI Customer Secret Key Secret
  }
}
