# Tenancy-level policy granting the OKE service permission to manage resources
# in the compartment (required once per compartment).
resource "oci_identity_policy" "oke_service" {
  count          = var.enable_oke_service_policy ? 1 : 0
  compartment_id = var.oci_tenancy_ocid
  name           = "oke-service-${random_pet.suffix.id}"
  description    = "Allow the OKE service to manage resources for the stack compartment."

  statements = [
    "Allow service OKE to manage all-resources in compartment id ${local.compartment_ocid}"
  ]
}

resource "oci_identity_policy" "oke_caller" {
  for_each = { for g in data.oci_identity_group.caller : g.name => g.name }

  compartment_id = var.oci_tenancy_ocid
  name           = "oke-caller-${random_pet.suffix.id}-${replace(each.key, "-", "_")}"
  description    = "Allow the calling user's groups to manage OKE cluster resources."

  statements = [
    "Allow group ${each.key} to manage cluster-family in compartment id ${local.compartment_ocid}"
  ]
}

# Workload-identity policies so the KubernetesClusterAutoscaler add-on can
# resize the node pool it is bound to. Only needed with authType=workload.
resource "oci_identity_policy" "cluster_autoscaler" {
  count          = var.enable_autoscaling ? 1 : 0
  compartment_id = local.compartment_ocid
  name           = "oke-cluster-autoscaler-${random_pet.suffix.id}"
  description    = "Allow the OKE cluster autoscaler workload to manage its node pool."

  statements = [
    "Allow any-user to manage cluster-node-pools in compartment id ${local.compartment_ocid} where request.principal.type = 'workload' AND request.principal.cluster_id = '${oci_containerengine_cluster.kronos.id}'",
    "Allow any-user to read all-resources in compartment id ${local.compartment_ocid} where request.principal.type = 'workload' AND request.principal.cluster_id = '${oci_containerengine_cluster.kronos.id}'",
  ]
}
