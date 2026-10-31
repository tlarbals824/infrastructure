terraform {
  required_version = ">= 1.17.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11.0"
    }
    # 5.x 는 Access, DNS, cloudflare_ip_ranges 속성 이름이 바뀌어 리소스를 다시 만든다.
    # 4.52 대의 최신 보안 패치에 고정한다.
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.52.10"
    }
  }

  # Terraform 1.17 은 PutObject 에 aws-chunked 체크섬을 붙인다. OCI 는 501 을 반환한다.
  # skip_s3_checksum 만으로는 빠지지 않으므로 워크플로에서
  # AWS_REQUEST_CHECKSUM_CALCULATION=when_required 와
  # AWS_RESPONSE_CHECKSUM_VALIDATION=when_required 를 설정한다.
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
