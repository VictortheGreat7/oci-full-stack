# The OKE cluster itself (network, node pool, autoscaler, kubeconfig) is created
# by the terraform/infra module. This module only manages in-cluster resources
# via the generated kubeconfig, so no cluster resources are defined here.

resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"

  namespace        = "metrics-server"
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/terraform-helm/metrics-server/values.yaml")]

  timeout = 600
}

resource "helm_release" "descheduler" {
  name       = "descheduler"
  repository = "https://kubernetes-sigs.github.io/descheduler/"
  chart      = "descheduler"

  namespace        = "kube-system"
  create_namespace = false

  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/terraform-helm/descheduler/values.yaml")]

  timeout = 600
}

module "infra" {
  source  = "./infra"

  oci_compartment_ocid = var.oci_compartment_ocid
}

# resource "kubernetes_service_account_v1" "headlamp-admin" {
#   metadata {
#     name      = "headlamp-admin"
#     namespace = "kube-system"
#   }
# }

# resource "kubernetes_cluster_role_binding_v1" "headlamp-admin" {
#   metadata {
#     name = "headlamp-admin"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = "headlamp-admin"
#     namespace = "kube-system"
#   }

#   depends_on = [kubernetes_service_account_v1.headlamp-admin]
# }

# resource "helm_release" "headlamp" {
#   name             = "headlamp"
#   repository       = "https://kubernetes-sigs.github.io/headlamp/"
#   chart            = "headlamp"
#   namespace        = "kube-system"
#   create_namespace = false
#   atomic           = true
#   cleanup_on_fail  = true

#   values = [
#     templatefile("${path.root}/terraform-helm/headlamp/values.yaml", {
#       headlamp_hostname = "${var.subdomains[5]}.${var.domain}"
#     })
#   ]

#   wait    = true
#   timeout = 600

#   depends_on = [kubernetes_cluster_role_binding_v1.headlamp-admin]
# }

# resource "kubernetes_token_request_v1" "headlamp-admin" {
#   metadata {
#     name      = kubernetes_service_account_v1.headlamp-admin.metadata.0.name
#     namespace = kubernetes_service_account_v1.headlamp-admin.metadata.0.namespace
#   }

#   depends_on = [helm_release.headlamp]
# }