# =============================================================================
# Cloudflare Access - Application & Policy
# =============================================================================

# =============================================================================
# ArgoCD Access Application
# =============================================================================

resource "cloudflare_access_application" "argocd" {
  zone_id          = var.cloudflare_zone_id
  name             = "ArgoCD"
  domain           = "argocd.${local.domain_name}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "argocd" {
  application_id = cloudflare_access_application.argocd.id
  zone_id        = var.cloudflare_zone_id
  name           = "Personal Access"
  precedence     = "1"
  decision       = "allow"

  include {
    email = var.cloudflare_allowed_emails
  }
}

# =============================================================================
# Nuclio Access Application
# =============================================================================

resource "cloudflare_access_application" "nuclio" {
  zone_id          = var.cloudflare_zone_id
  name             = "Serverless"
  domain           = "serverless.${local.domain_name}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "nuclio" {
  application_id = cloudflare_access_application.nuclio.id
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
locals {
  acme_challenge_hosts = {
    argocd     = "argocd.${local.domain_name}"
    serverless = "serverless.${local.domain_name}"
  }
}

resource "cloudflare_access_application" "acme_challenge" {
  for_each = local.acme_challenge_hosts

  zone_id              = var.cloudflare_zone_id
  name                 = "ACME ${each.key}"
  domain               = "${each.value}/.well-known/acme-challenge/*"
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
