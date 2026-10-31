data "oci_objectstorage_namespace" "tenancy" {
  compartment_id = var.tenancy_ocid
}

# LiveSync 덤프 5개만 보관한다. Terraform 상태 버킷과 분리한다.
resource "oci_objectstorage_bucket" "livesync_backup" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.tenancy.namespace
  name           = "livesync-backup"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"
}
