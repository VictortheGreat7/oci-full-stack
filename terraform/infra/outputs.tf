output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_name" {
  value = local.cluster_name
}

output "kubeconfig" {
  value     = yamlencode(module.oke.cluster_kubeconfig)
  sensitive = true
}

output "cluster_endpoints" {
  value = module.oke.cluster_endpoints
}

output "worker_pool_ids" {
  value = module.oke.worker_pool_ids
}

output "bastion_public_ip" {
  value = module.oke.bastion_public_ip
}
