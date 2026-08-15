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
  # tenancy_id is required: the module resolves it to the literal "unknown" if
  # unset, which makes dynamic-group creation (compartment_id = tenancy_id) fail
  # with 404-NotAuthorizedOrNotFound.
  tenancy_id     = var.oci_tenancy_ocid
  compartment_id = var.oci_compartment_ocid
  region         = var.oci_region

  # --- Cluster ---
  cluster_name                      = local.cluster_name
  cluster_type                      = "enhanced"
  kubernetes_version                = var.kubernetes_version
  cni_type                          = var.cni_type # "flannel" required for the module's built-in Cilium support
  control_plane_is_public           = true
  assign_public_ip_to_control_plane = true # easy kubectl access to the public API endpoint
  control_plane_allowed_cidrs       = ["0.0.0.0/0"]
  output_detail                     = true # expose cluster_kubeconfig / detailed outputs

  # --- SSH keys for the internal bastion -> operator deployment plumbing ---
  ssh_public_key  = tls_private_key.ssh.public_key_openssh
  ssh_private_key = tls_private_key.ssh.private_key_pem

  # VM.Standard.E4.Flex (the module default for both) has quota 0 in this
  # tenancy. Using E5.Flex 1 OCPU/4 GB for both (cheapest paid shape with
  # capacity). bastion_allowed_cidrs must allow the CI/apply runner to SSH.
  # Pin bastion + operator to AD-2 so they don't consume E5 quota in AD-1
  # (where the worker pool also places nodes).
  bastion_allowed_cidrs        = ["0.0.0.0/0"]
  bastion_availability_domain  = "CiWh:US-ASHBURN-AD-3"
  operator_availability_domain = "CiWh:US-ASHBURN-AD-3"
  bastion_shape = {
    shape                     = "VM.Standard3.Flex"
    ocpus                     = 1
    memory                    = 4
    boot_volume_size          = 50
    baseline_ocpu_utilization = 100
  }
  operator_shape = {
    shape                     = "VM.Standard3.Flex"
    ocpus                     = 1
    memory                    = 4
    boot_volume_size          = 50
    baseline_ocpu_utilization = 100
  }

  # --- IAM (dynamic groups + policies for the operator and Cluster Autoscaler) ---
  # Always created: the operator (used to deploy Cilium/autoscaler) needs its IAM
  # policy to fetch the kubeconfig via instance principal.
  create_iam_resources = true

  # --- Worker node pool ---
  # Maximize E5.Flex usage. The pool spreads across all 3 ADs
  # (placement_ads = [1,2,3]), and each AD caps at 13 E5 OCPU. With nodes spread
  # ~2/2/2, 6 nodes x 6 OCPU = 36 OCPU total / 12 OCPU per AD (<= 13), using
  # ~92% of the 39-OCPU E5 budget.
  worker_pools = {
    default = {
      shape            = "VM.Standard.E5.Flex"
      ocpus            = 2
      memory           = 16
      size             = 3
      min_size         = 3
      max_size         = 6
      boot_volume_size = var.node_disk_size_gbs
      image_type       = "oke"
      mode             = "node-pool"
      autoscale        = true
      allow_autoscaler = true
      placement_ads    = [1, 2, 3]
    }
  }

  # --- Cilium (installed by the module via the operator) ---
  cilium_install = true
  cilium_helm_version = "1.20.0"
  cilium_helm_values = {
    kubeProxyReplacement = true
    gatewayAPI = {
      enabled = true,
      gatewayClass = {
        create = "true"
      }
    } # the parent traffic stack uses the `cilium` GatewayClass
  }

  # --- Cluster Autoscaler (scale 4–6 nodes) ---
  cluster_autoscaler_install = true
  cluster_autoscaler_helm_version = "9.59.0"

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
