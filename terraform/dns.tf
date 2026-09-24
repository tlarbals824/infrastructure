# =============================================================================
# Cloudflare DNS - simproject.kr 도메인 관리
# =============================================================================

locals {
  # k8s/argocd-apps/infra.yaml 의 service.loadBalancerIP 와 같아야 한다.
  nlb_ip      = "134.185.104.125"
  domain_name = "simproject.kr"
  # 공개 호스트 이름. k8s/edge/hosts/<name> 폴더와 같은 키를 쓴다.
  public_hosts = toset(["argocd", "serverless"])
}

# =============================================================================
# DNS Records
# =============================================================================

moved {
  from = cloudflare_record.nuclio
  to   = cloudflare_record.serverless
}

moved {
  from = cloudflare_record.argocd
  to   = cloudflare_record.public["argocd"]
}

moved {
  from = cloudflare_record.serverless
  to   = cloudflare_record.public["serverless"]
}

resource "cloudflare_record" "public" {
  for_each = local.public_hosts

  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = local.nlb_ip
  type    = "A"
  proxied = true
  ttl     = 1
}
