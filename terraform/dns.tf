# =============================================================================
# OCI DNS - simproject.kr 도메인 관리
# =============================================================================
#
# 기존 DNS Zone이 이미 OCI에 있다면 import 후 사용하세요:
#   terraform import oci_dns_zone.simproject_kr <zone_ocid>
#
# =============================================================================

locals {
  nlb_ip      = "134.185.104.125"
  domain_name = "simproject.kr"
}

resource "oci_dns_zone" "simproject_kr" {
  compartment_id = var.compartment_ocid
  name           = local.domain_name
  zone_type      = "PRIMARY"

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# DNS A Records
# =============================================================================

resource "oci_dns_rrset" "n8n" {
  zone_name_or_id = oci_dns_zone.simproject_kr.id
  domain          = "n8n.${local.domain_name}"
  rtype           = "A"

  items {
    domain = "n8n.${local.domain_name}"
    rdata  = local.nlb_ip
    rtype  = "A"
    ttl    = 300
  }
}
