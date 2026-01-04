resource "oci_containerengine_cluster" "k8s" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.project_name}-cluster"
  vcn_id             = oci_core_vcn.k8s.id
  type               = "BASIC_CLUSTER"

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.api_endpoint.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.lb.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }
  }
}

resource "oci_containerengine_node_pool" "arm" {
  cluster_id         = oci_containerengine_cluster.k8s.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.project_name}-arm-pool"
  node_shape         = "VM.Standard.A1.Flex"

  node_shape_config {
    memory_in_gbs = 12
    ocpus         = 2
  }

  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.workers.id
    }
    size = 2
  }

  node_source_details {
    image_id    = data.oci_core_images.arm.images[0].id
    source_type = "IMAGE"
  }

  initial_node_labels {
    key   = "arch"
    value = "arm64"
  }
}

resource "oci_containerengine_node_pool" "amd" {
  cluster_id         = oci_containerengine_cluster.k8s.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.project_name}-amd-pool"
  node_shape         = "VM.Standard.E2.1.Micro"

  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.workers.id
    }
    size = 2
  }

  node_source_details {
    image_id    = data.oci_core_images.amd.images[0].id
    source_type = "IMAGE"
  }

  initial_node_labels {
    key   = "arch"
    value = "amd64"
  }

  initial_node_labels {
    key   = "workload"
    value = "lightweight"
  }
}
