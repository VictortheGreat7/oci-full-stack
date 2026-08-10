# Availability domains (single-region AD1 is enough for OKE).
data "oci_identity_availability_domains" "kronos" {
  compartment_id = local.compartment_ocid
}

# Latest supported kubelet/API versions for the region.
data "oci_containerengine_cluster_option" "kronos" {
  cluster_option_id = "all"
  compartment_id    = local.compartment_ocid
}

# The calling user authenticates as the tenancy root (or an administrator), so
# no extra caller policy is required - Tenant Admin Policy already grants full
# access to manage cluster-family resources.
