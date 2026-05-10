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
