# =============================================================================
# OCI DNS - simproject.kr 도메인 관리
# =============================================================================

locals {
  nlb_ip      = "134.185.104.125"
  domain_name = "simproject.kr"
}

data "oci_dns_zones" "simproject_kr" {
  compartment_id = var.compartment_ocid
  name           = local.domain_name
  zone_type      = "PRIMARY"
}
