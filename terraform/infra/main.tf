locals {
  cluster_name = coalesce(var.cluster_name, "kronos-${random_pet.suffix.id}")

  # Latest K8s version supported by OKE in the region unless pinned.
  kubernetes_version = var.kubernetes_version != "" ? var.kubernetes_version : data.oci_containerengine_cluster_option.kronos.kubernetes_versions[0]

  availability_domain = data.oci_identity_availability_domains.kronos.availability_domains[0].name
}

resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

resource "oci_containerengine_cluster" "kronos" {
  compartment_id     = local.compartment_ocid
  vcn_id             = oci_core_vcn.kronos.id
  kubernetes_version = local.kubernetes_version
  name               = local.cluster_name
  type               = "ENHANCED_CLUSTER" # required for autoscaler workload identity

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.api.id
    nsg_ids              = [oci_core_security_list.api.id]
  }

  cluster_pod_network_options {
    cni_type = var.cni_type
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.lb.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      services_cidr = var.services_cidr
      # With VCN-native pod networking pods are addressed from the VCN pod
      # subnet, so no separate pod CIDR is set on the cluster.
      pods_cidr = null
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }
  }
}

resource "oci_containerengine_node_pool" "kronos" {
  cluster_id         = oci_containerengine_cluster.kronos.id
  compartment_id     = local.compartment_ocid
  kubernetes_version = local.kubernetes_version
  name               = "${local.cluster_name}-nodepool"
  node_shape         = var.node_shape

  node_shape_config {
    ocpus         = var.node_shape_ocpus
    memory_in_gbs = var.node_shape_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = var.node_image_id # OKE Oracle-Linux-9.8 x86 image (us-ashburn-1)
    boot_volume_size_in_gbs = var.node_disk_size_gbs
  }

  node_config_details {
    size = var.node_pool_size

    placement_configs {
      availability_domain = local.availability_domain
      subnet_id           = oci_core_subnet.nodes.id
    }

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids = [oci_core_subnet.pods.id]
    }
  }

  initial_node_labels {
    key   = "oke.oraclecloud.com/cluster_autoscaler"
    value = "managed"
  }

  # The autoscaler add-on manages the node count; ignore drift from it.
  lifecycle {
    ignore_changes = [node_config_details[0].size]
  }
}

resource "oci_containerengine_addon" "cluster_autoscaler" {
  count                            = var.enable_autoscaling ? 1 : 0
  cluster_id                       = oci_containerengine_cluster.kronos.id
  addon_name                       = "KubernetesClusterAutoscaler"
  remove_addon_resources_on_delete = true

  configurations {
    key   = "nodes"
    value = "${var.node_pool_min_size}:${var.node_pool_max_size}:${oci_containerengine_node_pool.kronos.id}"
  }
  configurations {
    key   = "authType"
    value = "workload"
  }
  configurations {
    key   = "numOfReplicas"
    value = "2"
  }
  configurations {
    key   = "maxNodeProvisionTime"
    value = "25m"
  }
  configurations {
    key   = "scaleDownDelayAfterAdd"
    value = "15m"
  }
  configurations {
    key   = "scaleDownUnneededTime"
    value = "10m"
  }
}

# Kubeconfig for the creating user (gets cluster-admin by default). The file is
# emitted as an OCI CLI `exec` plugin config, so the client needs oci-cli and a
# valid OCI config (or OCI_* env vars) to refresh the token.
data "oci_containerengine_cluster_kube_config" "kronos" {
  cluster_id    = oci_containerengine_cluster.kronos.id
  endpoint      = "PUBLIC_ENDPOINT"
  token_version = "2.0.0"
}

resource "local_file" "kubeconfig" {
  filename        = abspath("${path.module}/../kubeconfig")
  content         = data.oci_containerengine_cluster_kube_config.kronos.content
  file_permission = "0600"
}
