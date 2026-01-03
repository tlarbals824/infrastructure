# OCI Provider Configuration
# 환경변수에서 인증 정보를 자동으로 읽어옵니다:
# - TF_VAR_tenancy_ocid
# - TF_VAR_user_ocid
# - TF_VAR_fingerprint
# - TF_VAR_private_key_path
# - TF_VAR_region

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
