# Availability domains (single-region AD1 is enough for OKE).
data "oci_identity_availability_domains" "kronos" {
  compartment_id = local.compartment_ocid
}

# Latest supported kubelet/API versions for the region.
data "oci_containerengine_cluster_option" "kronos" {
  cluster_option_id = "all"
  compartment_id    = local.compartment_ocid
}

# Groups the calling user (var.oci_user_ocid) belongs to. Used to grant the
# caller manage cluster-family so it can create/manage the OKE cluster.
data "oci_identity_user_group_memberships" "caller" {
  count          = var.oci_user_ocid != "" ? 1 : 0
  compartment_id = var.oci_tenancy_ocid
  user_id        = var.oci_user_ocid
}

data "oci_identity_group" "caller" {
  for_each = toset(data.oci_identity_user_group_memberships.caller[*].memberships[*].group_id)
  group_id = each.value
}
