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

  # A1 Always Free 는 노드 두 대가 할당량을 다 쓴다. surge 로 세 번째 인스턴스를
  # 만들면 실패하거나, 예전 인스턴스와 부트 볼륨이 같이 남아 비용이 청구된다.
  # INSTANCE_REPLACE 는 인스턴스를 종료하면서 부트 볼륨을 지우고 그 자리에 만든다.
  # BOOT_VOLUME_REPLACE 는 인스턴스를 남긴 채 볼륨만 갈아 예전 볼륨이 남을 수 있다.
  node_pool_cycling_details {
    is_node_cycling_enabled = true
    cycle_modes             = ["INSTANCE_REPLACE"]
    maximum_surge           = "0"
    maximum_unavailable     = "1"
  }

  # 드레인이 멈추면 예전 노드가 종료되지 않는다. surge 가 0 이라 새 노드도
  # 생기지 않고 업그레이드만 멈춘다. 유예 뒤에 강제 삭제해 인스턴스와 부트 볼륨을 지운다.
  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT20M"
    is_force_action_after_grace_duration = true
    is_force_delete_after_grace_duration = true
  }

  timeouts {
    update = "90m"
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
