# Availability domains (single-region AD1 is enough for OKE).
data "oci_identity_availability_domains" "kronos" {
  compartment_id = local.compartment_ocid
}

# Latest supported kubelet/API versions for the region.
data "oci_containerengine_cluster_option" "kronos" {
  cluster_option_id = "all"
  compartment_id    = local.compartment_ocid
}

data "oci_core_images" "oke_nodes" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.node_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "display_name"
    values = ["^Oracle-Linux-9.*-OKE-${local.kubernetes_version}-.*$"]
    regex  = true
  }
}

# The calling user authenticates as the tenancy root (or an administrator), so
# no extra caller policy is required - Tenant Admin Policy already grants full
# access to manage cluster-family resources.
