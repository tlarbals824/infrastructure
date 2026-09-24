# =============================================================================
# Cloudflare Access - Application & Policy
# =============================================================================

moved {
  from = cloudflare_access_application.argocd
  to   = cloudflare_access_application.public["argocd"]
}

moved {
  from = cloudflare_access_application.nuclio
  to   = cloudflare_access_application.public["serverless"]
}

moved {
  from = cloudflare_access_policy.argocd
  to   = cloudflare_access_policy.public["argocd"]
}

moved {
  from = cloudflare_access_policy.nuclio
  to   = cloudflare_access_policy.public["serverless"]
}

resource "cloudflare_access_application" "public" {
  for_each = local.public_hosts

  zone_id          = var.cloudflare_zone_id
  name             = each.key
  domain           = "${each.key}.${local.domain_name}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "public" {
  for_each = cloudflare_access_application.public

  application_id = each.value.id
  zone_id        = var.cloudflare_zone_id
  name           = "Personal Access"
  precedence     = "1"
  decision       = "allow"

  include {
    email = var.cloudflare_allowed_emails
  }
}

# =============================================================================
# Zone Settings - SSL/TLS
# =============================================================================

# Let's Encrypt HTTP-01 은 /.well-known/acme-challenge/ 가 공개여야 한다.
# 경로가 더 구체적인 Access 애플리케이션이 호스트 전체 정책보다 우선한다.
# 이 바이패스가 없으면 인증서 발급을 위해 Access 를 잠시 지워야 한다.
resource "cloudflare_access_application" "acme_challenge" {
  for_each = local.public_hosts

  zone_id              = var.cloudflare_zone_id
  name                 = "ACME ${each.key}"
  domain               = "${each.key}.${local.domain_name}/.well-known/acme-challenge/*"
  type                 = "self_hosted"
  session_duration     = "1h"
  app_launcher_visible = false
}

resource "cloudflare_access_policy" "acme_challenge" {
  for_each = cloudflare_access_application.acme_challenge

  application_id = each.value.id
  zone_id        = var.cloudflare_zone_id
  name           = "Bypass ACME HTTP-01"
  precedence     = "1"
  decision       = "bypass"

  include {
    everyone = true
  }
}

resource "cloudflare_zone_settings_override" "simproject_kr" {
  zone_id = var.cloudflare_zone_id

  settings {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
  }
}
