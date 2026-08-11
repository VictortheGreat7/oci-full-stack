locals {
  compartment_ocid = var.oci_compartment_ocid != "" ? var.oci_compartment_ocid : var.oci_tenancy_ocid

  # Subnet CIDRs carved out of the VCN.
  lb_subnet_cidr    = cidrsubnet(var.vcn_cidr, 8, 0) # 10.240.0.0/24 (public, LoadBalancers)
  api_subnet_cidr   = cidrsubnet(var.vcn_cidr, 8, 1) # 10.240.1.0/24 (public, API endpoint)
  nodes_subnet_cidr = cidrsubnet(var.vcn_cidr, 8, 2) # 10.240.2.0/24 (private, nodes)
  pods_subnet_cidr  = cidrsubnet(var.vcn_cidr, 8, 3) # 10.240.3.0/24 (private, VCN-native pod IPs)
}

# --- VCN ---
resource "oci_core_vcn" "kronos" {
  compartment_id = local.compartment_ocid
  cidr_block     = var.vcn_cidr
  display_name   = "${local.cluster_name}-vcn"
  dns_label      = "kronos"
}

# --- Gateways ---
resource "oci_core_internet_gateway" "kronos" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-igw"
  enabled        = true
}

resource "oci_core_nat_gateway" "kronos" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-natgw"
  block_traffic  = false
}

# Private path to OCI regional services (registry, object storage, OKE API).
# service_id is the regional "All ... Services In Oracle Services Network"
# entry; fetch with: oci network service list --region REGION
resource "oci_core_service_gateway" "kronos" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-svcgw"
  services {
    service_id = var.network_service_id
  }
}

# --- Route tables ---
resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.kronos.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.kronos.id
  }
  route_rules {
    destination       = "all-iad-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.kronos.id
  }
}

# --- Subnets ---
resource "oci_core_subnet" "lb" {
  compartment_id    = local.compartment_ocid
  vcn_id            = oci_core_vcn.kronos.id
  cidr_block        = local.lb_subnet_cidr
  display_name      = "${local.cluster_name}-lb-subnet"
  dns_label         = "lb"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.lb.id]
}

resource "oci_core_subnet" "api" {
  compartment_id    = local.compartment_ocid
  vcn_id            = oci_core_vcn.kronos.id
  cidr_block        = local.api_subnet_cidr
  display_name      = "${local.cluster_name}-api-subnet"
  dns_label         = "api"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.api.id]
}

resource "oci_core_subnet" "nodes" {
  compartment_id             = local.compartment_ocid
  vcn_id                     = oci_core_vcn.kronos.id
  cidr_block                 = local.nodes_subnet_cidr
  display_name               = "${local.cluster_name}-nodes-subnet"
  dns_label                  = "nodes"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.nodes.id]
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_subnet" "pods" {
  compartment_id             = local.compartment_ocid
  vcn_id                     = oci_core_vcn.kronos.id
  cidr_block                 = local.pods_subnet_cidr
  display_name               = "${local.cluster_name}-pods-subnet"
  dns_label                  = "pods"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.pods.id]
  prohibit_public_ip_on_vnic = true
}

# --- Security lists (keep ports minimal) ---
resource "oci_core_security_list" "lb" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-lb-sl"

  ingress_security_rules {
    protocol = "6" # TCP
    source   = var.lb_ingress_cidrs[0]
    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = var.lb_ingress_cidrs[0]
    tcp_options {
      min = 80
      max = 80
    }
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "api" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-api-sl"

  ingress_security_rules {
    protocol = "6"
    source   = var.api_endpoint_ingress_cidrs[0]
    tcp_options {
      min = 6443
      max = 6443
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/8" # VCN-private (CNI control plane)
    tcp_options {
      min = 6443
      max = 6443
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "${oci_core_nat_gateway.kronos.nat_ip}/32"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
  ingress_security_rules {
    protocol = "1" # OCI identifier for ICMP
    source   = "0.0.0.0/0"
    
    icmp_options {
      type = 3
      code = 4
    }
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "nodes" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-nodes-sl"

  # VCN-private traffic between nodes (CNI, kubelet, pods).
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/8"
  }
  # kubelet from the API server subnet.
  ingress_security_rules {
    protocol = "6"
    source   = local.api_subnet_cidr
    tcp_options {
      min = 10250
      max = 10250
    }
  }
  # NodePort from the LB subnet.
  ingress_security_rules {
    protocol = "6"
    source   = local.lb_subnet_cidr
    tcp_options {
      min = 30000
      max = 32767
    }
  }
  # kube-proxy health-check port from the LB subnet.
  ingress_security_rules {
    protocol = "6"
    source   = local.lb_subnet_cidr
    tcp_options {
      min = 10256
      max = 10256
    }
  }
  ingress_security_rules {
    protocol = "1" # OCI identifier for ICMP
    source   = "0.0.0.0/0"
    
    icmp_options {
      type = 3
      code = 4
    }
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_security_list" "pods" {
  compartment_id = local.compartment_ocid
  vcn_id         = oci_core_vcn.kronos.id
  display_name   = "${local.cluster_name}-pods-sl"

  # Pods talk freely inside the VCN (nodes, API server, LB).
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/8"
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0" # outbound internet via NAT gateway
  }
}
