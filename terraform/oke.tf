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

  # 클러스터를 다시 만들면 CCM 이 만든 NLB 와 블록 볼륨이 상태 밖에 남는다.
  lifecycle {
    prevent_destroy = true
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
    image_id    = local.oke_arm_worker_image_id
    source_type = "IMAGE"
  }

  # 이 클러스터는 BASIC_CLUSTER 다. 노드 순환(node_pool_cycling_details)과
  # 노드 풀 축출 설정은 Enhanced 전용이라 UpdateNodePool 이 400 으로 거절한다.
  # Enhanced 로 올리면 클러스터 관리 비용이 생긴다. 버전과 이미지만 풀에 기록하고,
  # 떠 있는 노드는 scripts/replace_basic_oke_nodes.sh 가 한 대씩 지우고 교체한다.

  timeouts {
    update = "30m"
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = length(local.compatible_oke_arm_worker_images) > 0
      error_message = "No compatible OKE Oracle Linux 8 aarch64 worker image found for the configured Kubernetes version and minimum image build."
    }
  }

  initial_node_labels {
    key   = "arch"
    value = "arm64"
  }
}
