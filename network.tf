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
}

resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k8s.id
  display_name   = "${var.project_name}-lb-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
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
