# =============================================================================
# Cloudflare DNS - simproject.kr 도메인 관리
# =============================================================================

locals {
  # k8s/argocd-apps/infra.yaml 의 controller.service.loadBalancerIP 와 같아야 한다.
  nlb_ip      = "134.185.104.125"
  domain_name = "simproject.kr"
}

# =============================================================================
# DNS Records
# =============================================================================

resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argocd"
  content = local.nlb_ip
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "nuclio" {
  zone_id = var.cloudflare_zone_id
  name    = "nuclio"
  content = local.nlb_ip
  type    = "A"
  proxied = true
  ttl     = 1
}
