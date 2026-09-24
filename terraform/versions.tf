terraform {
  required_version = ">= 1.10.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.24.0"
    }
    # 5.x 는 cloudflare_ip_ranges 속성 이름이 바뀐다. 4.52 대에 고정한다.
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52.8"
    }
  }

  backend "s3" {
    bucket = "terraform"
    key    = "terraform.tfstate"
    region = "us-east-1"

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
