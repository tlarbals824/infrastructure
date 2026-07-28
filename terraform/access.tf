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
    service_token = [var.argo_dex_service_token_id]
  }
}

# =============================================================================
# Zone Settings - SSL/TLS
# =============================================================================

resource "cloudflare_zone_settings_override" "simproject_kr" {
  zone_id = var.cloudflare_zone_id

  settings {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
  }
}
