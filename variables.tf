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

variable "private_key_path" {
  description = "Path to the API private key file"
  type        = string
}

variable "region" {
  description = "OCI Region (e.g., ap-seoul-1, ap-tokyo-1)"
  type        = string
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

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "common_tags" {
  description = "Common freeform tags for all resources"
  type        = map(string)
  default     = {}
}
