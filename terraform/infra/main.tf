locals {
  cluster_name = coalesce(var.cluster_name, "kronos-${random_pet.suffix.id}")
}

resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

# Ephemeral keypair for the module's internal bastion -> operator SSH plumbing
# (used only to deploy Cilium/Cluster Autoscaler; not for user access).
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "oke" {
  source  = "oracle-terraform-modules/oke/oci"
  version = "~> 5.0"

  providers = {
    oci      = oci
    oci.home = oci.home
  }

  # --- Tenancy / Compartment ---
  compartment_id = var.oci_compartment_ocid
  region         = var.oci_region

  # --- Cluster ---
  cluster_name                   = local.cluster_name
  cluster_type                   = "enhanced"
  kubernetes_version             = var.kubernetes_version
  cni_type                       = var.cni_type # "flannel" required for the module's built-in Cilium support
  control_plane_is_public        = true
  assign_public_ip_to_control_plane = true # easy kubectl access to the public API endpoint
  output_detail                  = true      # expose cluster_kubeconfig / detailed outputs

  # --- SSH keys for the internal bastion -> operator deployment plumbing ---
  ssh_public_key  = tls_private_key.ssh.public_key_openssh
  ssh_private_key = tls_private_key.ssh.private_key_pem

  # --- IAM (dynamic groups + policies for the operator and Cluster Autoscaler) ---
  # Always created: the operator (used to deploy Cilium/autoscaler) needs its IAM
  # policy to fetch the kubeconfig via instance principal.
  create_iam_resources = true

  # --- Worker node pool: 4 OCPU / 8 GB RAM, 3–5 nodes ---
  worker_pools = {
    default = {
      shape            = "VM.Standard.E5.Flex"
      ocpus            = 4
      memory           = 8
      size             = 3
      min_size         = var.node_pool_min_size
      max_size         = var.node_pool_max_size
      boot_volume_size = var.node_disk_size_gbs
      image_type       = "oke"
      mode             = "node-pool"
      autoscale        = var.enable_autoscaling
      allow_autoscaler = var.enable_autoscaling
    }
  }

  # --- Cilium (installed by the module via the operator) ---
  cilium_install = true
  cilium_helm_values = {
    gatewayAPI = { enabled = true } # the parent traffic stack uses the `cilium` GatewayClass
  }

  # --- Cluster Autoscaler (installed by the module via Helm) ---
  cluster_autoscaler_install = var.enable_autoscaling

  # --- Tags (nested map: one tag set per resource type) ---
  freeform_tags = {
    bastion           = {}
    cluster           = var.labels
    iam               = {}
    network           = {}
    operator          = {}
    persistent_volume = {}
    service_lb        = {}
    workers           = var.labels
  }
}

# Kubeconfig consumed by the parent workspace (oci-full-stack) and by kubectl.
resource "local_file" "kubeconfig" {
  content         = yamlencode(module.oke.cluster_kubeconfig)
  filename        = abspath("${path.module}/../kubeconfig")
  file_permission = "0600"
}
