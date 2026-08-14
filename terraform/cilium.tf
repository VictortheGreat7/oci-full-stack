# Gateway API CRDs. The gateway chart requires
# these; neither the chart nor Cilium installs them itself.
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml"
}

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

resource "kubernetes_manifest" "gateway_api_crd" {
  for_each = local.gateway_api_manifests
  manifest = each.value

  wait {
    field_path     = "status.conditions[?(@.type==\"Established\")].status"
    equal_to       = "True"
    timeout        = "5m"
    absent_timeout = "5m"
  }

  depends_on = [module.oke]
}

resource "null_resource" "restart_cilium_operator" {
  triggers = {
    cluster_id = module.oke.cluster_id
    crds_hash  = sha256(jsonencode(local.gateway_api_manifests))
  }

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG=${abspath("${path.module}/../kubeconfig")} \
      kubectl rollout restart deployment/cilium-operator -n kube-system
    EOT
  }

  depends_on = [
    module.oke,
    kubernetes_manifest.gateway_api_crd
  ]
}
