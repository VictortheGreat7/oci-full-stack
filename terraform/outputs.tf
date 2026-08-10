output "cluster_name" {
  description = "Name of the OKE cluster (from the infra module)."
  value       = var.cluster_name
}

# output "tokenValue" {
#   value     = kubernetes_token_request_v1.headlamp-admin.token
#   sensitive = true
# }
