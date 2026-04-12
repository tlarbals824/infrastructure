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

# =============================================================================
# DNS A Records
# =============================================================================

resource "oci_dns_rrset" "n8n" {
  zone_name_or_id = data.oci_dns_zones.simproject_kr.zones[0].id
  domain          = "n8n.${local.domain_name}"
  rtype           = "A"

  items {
    domain = "n8n.${local.domain_name}"
    rdata  = local.nlb_ip
    rtype  = "A"
    ttl    = 300
  }
}
