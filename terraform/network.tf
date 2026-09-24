resource "oci_core_vcn" "k8s" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.project_name}-vcn"
  dns_label      = var.project_name
}

resource "oci_core_internet_gateway" "k8s" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-igw"
  enabled        = true
}

resource "oci_core_nat_gateway" "k8s" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-nat"
}

resource "oci_core_service_gateway" "k8s" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-sg"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.k8s.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-private-rt"

  route_rules {
    network_entity_id = oci_core_nat_gateway.k8s.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }

  route_rules {
    network_entity_id = oci_core_service_gateway.k8s.id
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "api_endpoint" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-api-endpoint-sl"

  egress_security_rules {
    protocol         = "6"
    destination      = data.oci_core_services.all_services.services[0].cidr_block
    destination_type = "SERVICE_CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = "10.0.1.0/24"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    protocol    = "6"
    destination = "10.0.1.0/24"
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  egress_security_rules {
    protocol    = "1"
    destination = "10.0.1.0/24"
    icmp_options {
      type = 3
      code = 4
    }
  }

  # API 엔드포인트는 퍼블릭이다. kubectl 을 쓰는 IP 가 정해지면 source 를 그 CIDR 로 좁힌다.
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.1.0/24"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.1.0/24"
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "10.0.1.0/24"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_security_list" "workers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-workers-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  # NLB 는 소스 IP 를 보존한다. 공개 HTTP 는 Cloudflare 를 통하므로 NodePort 는
  # Cloudflare IPv4 만 연다. NLB 헬스체크는 위의 10.0.0.0/16 규칙으로 허용된다.
  dynamic "ingress_security_rules" {
    for_each = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)
    content {
      description = "NodePort from Cloudflare"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 30000
        max = 32767
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks) > 0
      error_message = "Cloudflare IPv4 range list is empty. Refusing to update the worker security list."
    }
  }
}

resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-lb-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # 리스너로 들어오는 공개 트래픽은 Cloudflare 엣지만 허용한다.
  # 오리진 IP 로 직접 붙으면 Argo CD anonymous admin, Nuclio nop auth 를 우회할 수 있다.
  dynamic "ingress_security_rules" {
    for_each = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)
    content {
      description = "HTTP from Cloudflare"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 80
        max = 80
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks)
    content {
      description = "HTTPS from Cloudflare"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 443
        max = 443
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks) > 0
      error_message = "Cloudflare IPv4 range list is empty. Refusing to update the load balancer security list."
    }
  }
}

resource "oci_core_subnet" "api_endpoint" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.k8s.id
  cidr_block        = "10.0.0.0/28"
  display_name      = "${var.project_name}-api-endpoint-subnet"
  dns_label         = "api"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.api_endpoint.id]
}

resource "oci_core_subnet" "lb" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.k8s.id
  cidr_block        = "10.0.0.16/28"
  display_name      = "${var.project_name}-lb-subnet"
  dns_label         = "lb"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.lb.id]
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.k8s.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "${var.project_name}-workers-subnet"
  dns_label                  = "workers"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.workers.id]
  prohibit_public_ip_on_vnic = true
}
