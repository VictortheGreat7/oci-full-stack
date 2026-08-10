# Gateway API CRDs (v1.6.1, standard channel). The Cilium chart and the
# subshell `gateway` chart both require these; neither installs them itself.
# Each CRD is applied with kubernetes_manifest from the bundled manifests.
locals {
  gateway_api_crds = toset(fileset("${path.root}/manifests/gateway-api", "*.yaml"))
}

resource "kubernetes_manifest" "gateway_api_crd" {
  for_each = local.gateway_api_crds

  manifest = yamldecode(file("${path.root}/manifests/gateway-api/${each.value}"))
}

# Cilium in OKE CNI chaining mode. Provides the `cilium` GatewayClass used by
# the traffic stack's Gateway (terraform-helm/traffic/gateway).
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.20.0"

  namespace        = "kube-system"
  create_namespace = false

  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/terraform-helm/cilium/values.yaml")]

  wait    = true
  timeout = 900

  depends_on = [kubernetes_manifest.gateway_api_crd]
}
