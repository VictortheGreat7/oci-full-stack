# Fetch latest Gateway API CRDs
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml"
}

# Split multi-doc YAML into individual manifests
locals {
  gateway_api_docs = [
    for doc in split("\n---\n", data.http.gateway_api_crds.response_body)
    : yamldecode(doc)
    if length(trimspace(doc)) > 0
  ]

  gateway_api_manifests = {
    for doc in local.gateway_api_docs :
    "${doc.apiVersion}/${doc.kind}/${doc.metadata.name}" => doc
  }
}

# Install CRDs
resource "kubernetes_manifest" "gateway_api_crd" {
  for_each = local.gateway_api_manifests

  manifest = each.value

  depends_on = [module.infra]
}

# Give the API server a moment to register CRDs
resource "time_sleep" "wait_for_crds" {
  create_duration = "30s"

  depends_on = [kubernetes_manifest.gateway_api_crd]
}

# Restart Cilium operator after CRDs exist
resource "null_resource" "restart_cilium_operator" {
  triggers = {
    cluster_id = module.infra.cluster_id
    crds_hash  = sha256(jsonencode(local.gateway_api_manifests))
  }

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG=${abspath("${path.module}/../kubeconfig")} \
      kubectl rollout restart deployment/cilium-operator -n kube-system

      KUBECONFIG=${abspath("${path.module}/../kubeconfig")} \
      kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=120s || true
    EOT
  }

  depends_on = [
    module.infra,
    time_sleep.wait_for_crds
  ]
}