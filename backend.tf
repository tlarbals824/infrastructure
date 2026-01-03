terraform {
  backend "s3" {
    bucket = "terraform"
    key    = "terraform.tfstate"
    region = "ap-chuncheon-1"

    endpoints = {
      s3 = "https://axgu3qzufd5m.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
