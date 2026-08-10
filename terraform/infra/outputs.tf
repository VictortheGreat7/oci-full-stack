output "cluster_id" {
  description = "OCID of the OKE cluster."
  value       = oci_containerengine_cluster.kronos.id
}

output "cluster_name" {
  description = "Name of the OKE cluster."
  value       = local.cluster_name
}

output "node_pool_ocid" {
  description = "OCID of the node pool."
  value       = oci_containerengine_node_pool.kronos.id
}

output "node_pool_min_size" {
  description = "Autoscaler minimum nodes."
  value       = var.node_pool_min_size
}

output "node_pool_max_size" {
  description = "Autoscaler maximum nodes."
  value       = var.node_pool_max_size
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster."
  value       = local.kubernetes_version
}

output "region" {
  description = "OCI region where the cluster lives."
  value       = var.oci_region
}

output "compartment_ocid" {
  description = "OCID of the compartment holding the stack."
  value       = local.compartment_ocid
}

output "kubeconfig_path" {
  description = "Absolute path of the generated kubeconfig file."
  value       = abspath("${path.module}/../kubeconfig")
}
