# Wait for cluster to exist (depends on your OKE module output)
resource "null_resource" "install_gateway_api_crds" {
  triggers = {
    cluster_id = var.cluster_id
    # Change this to force re-apply when you want to upgrade CRDs:
    crd_version = "latest"
  }

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG=${abspath("${path.module}/kubeconfig")} \
      kubectl apply --server-side -f \
        https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml

      # Wait until core Gateway API CRDs are established
      KUBECONFIG=${abspath("${path.module}/kubeconfig")} \
      kubectl wait --for=condition=Established \
        crd/gateways.gateway.networking.k8s.io \
        crd/gatewayclasses.gateway.networking.k8s.io \
        crd/httproutes.gateway.networking.k8s.io \
        --timeout=120s
    EOT
  }
}

# Restart Cilium operator after CRDs exist
resource "null_resource" "restart_cilium_operator" {
  triggers = {
    cluster_id = var.cluster_id
    crds_hash  = sha256("${null_resource.install_gateway_api_crds.id}")
  }

  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG=${abspath("${path.module}/kubeconfig")} \
      kubectl rollout restart deployment/cilium-operator -n kube-system
    EOT
  }

  depends_on = [null_resource.install_gateway_api_crds]
}