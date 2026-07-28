# =============================================================================
# Provider Variables (Required)
# =============================================================================

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "API Key fingerprint"
  type        = string
}

variable "private_key" {
  description = "OCI API private key content"
  type        = string
  sensitive   = true
}



variable "compartment_ocid" {
  description = "Compartment OCID for resources"
  type        = string
}

# =============================================================================
# Common Variables
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "myproject"
}



variable "common_tags" {
  description = "Common freeform tags for all resources"
  type        = map(string)
  default     = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE cluster"
  type        = string
  default     = "v1.35.2"
}

variable "oke_minimum_image_build" {
  description = "Minimum OKE Oracle Linux 8 worker image build. Kubernetes 1.35 requires cgroups v2, which OKE OL8 images enable by default starting at build 1367."
  type        = number
  default     = 1367
}

# =============================================================================
# Cloudflare Variables
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for simproject.kr"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_allowed_emails" {
  description = "List of email addresses allowed to access services"
  type        = list(string)
  default     = ["srfsrf0103@gmail.com"]
}

variable "argo_dex_service_token_id" {
  description = "Cloudflare Access Service Token ID for ArgoCD Dex OIDC integration"
  type        = string
  default     = "408d031f-508e-4668-9c88-9f832d37f546"
}
