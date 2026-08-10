# Availability domains (single-region AD1 is enough for OKE).
data "oci_identity_availability_domains" "kronos" {
  compartment_id = local.compartment_ocid
}

# Latest supported kubelet/API versions for the region.
data "oci_containerengine_cluster_option" "kronos" {
  cluster_option_id = "all"
  compartment_id    = local.compartment_ocid
}

# Node pool option exposes the OKE-ready images for a shape.
data "oci_containerengine_node_pool_option" "kronos" {
  node_pool_option_id = "all"
  compartment_id      = local.compartment_ocid
}

# Service Gateway service CIDR (e.g. all-ix-services-in-oci).
data "oci_core_services" "kronos" {}
