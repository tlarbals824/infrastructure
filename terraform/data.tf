data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

data "oci_containerengine_node_pool_option" "oke" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

locals {
  kubernetes_version_without_prefix = trimprefix(lower(var.kubernetes_version), "v")

  compatible_oke_arm_worker_images = [
    for source in data.oci_containerengine_node_pool_option.oke.sources : {
      id    = source.image_id
      name  = source.source_name
      build = try(tonumber(regex("OKE-[0-9.]+-([0-9]+)", source.source_name)[0]), 0)
    }
    if source.source_type == "IMAGE"
    && can(regex("OKE-${local.kubernetes_version_without_prefix}-", source.source_name))
    && can(regex("aarch64", source.source_name))
    && can(regex("Oracle-Linux-?8", source.source_name))
    && try(tonumber(regex("OKE-[0-9.]+-([0-9]+)", source.source_name)[0]), 0) >= var.oke_minimum_image_build
  ]

  oke_arm_worker_image_id = try(element(split("###", element(reverse(sort([
    for image in local.compatible_oke_arm_worker_images : format("%012d###%s", image.build, image.id)
  ])), 0)), 1), null)
}
