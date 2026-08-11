# Gateway API CRDs (v1.6.1, standard channel). The gateway chart requires
# these; neither the chart nor Cilium installs them itself.
locals {
  gateway_api_crds = toset(fileset("${path.root}/manifests/gateway-api", "*.yaml"))
}

resource "kubernetes_manifest" "gateway_api_crd" {
  for_each = local.gateway_api_crds

  manifest = yamldecode(file("${path.root}/manifests/gateway-api/${each.value}"))
}
