# --- OCI / provider context ---
variable "oci_tenancy_ocid" {
  description = "OCID of the tenancy (root compartment)."
  type        = string
  default     = ""
}

variable "oci_compartment_ocid" {
  description = "OCID of the compartment where the stack is created."
  type        = string
}

variable "oci_region" {
  description = "OCI region short code, e.g. us-ashburn-1."
  type        = string
  default     = "us-ashburn-1"
}

# --- OCI API key credentials (set these in HCP Terraform Cloud) ---
# Leave empty to fall back to OCI_* env vars or ~/.oci/config for local runs.
variable "oci_user_ocid" {
  description = "OCID of the OCI user that Terraform runs as."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oci_fingerprint" {
  description = "Fingerprint of the user's API key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oci_private_key" {
  description = "Contents of the user's API private key (PEM). Prefer over oci_private_key_path in Terraform Cloud."
  type        = string
  default     = ""
  sensitive   = true
}

variable "oci_private_key_path" {
  description = "Filesystem path to the user's API private key. Leave empty in Terraform Cloud (no shared filesystem)."
  type        = string
  default     = ""
  sensitive   = true
}

# --- Cluster / node pool ---
variable "cluster_name" {
  description = "Name of the OKE cluster. Defaults to a random_pet suffix."
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version to install (empty = latest from the region)."
  type        = string
  default     = ""
}

variable "cni_type" {
  description = "CNI to use. CI_BASED = OKE-managed Cilium (required by the traffic stack)."
  type        = string
  default     = "CI_BASED"
}

variable "node_shape" {
  description = "Instance shape for the node pool."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_shape_ocpus" {
  description = "Number of OCPUs per node."
  type        = number
  default     = 2
}

variable "node_shape_memory_gbs" {
  description = "Memory (GiB) per node."
  type        = number
  default     = 8
}

variable "node_disk_size_gbs" {
  description = "Boot volume size (GiB) per node."
  type        = number
  default     = 50
}

variable "node_pool_size" {
  description = "Initial number of nodes."
  type        = number
  default     = 1
}

variable "node_pool_min_size" {
  description = "Minimum number of nodes for the autoscaler."
  type        = number
  default     = 1
}

variable "node_pool_max_size" {
  description = "Maximum number of nodes for the autoscaler."
  type        = number
  default     = 3
}

variable "enable_autoscaling" {
  description = "Install the KubernetesClusterAutoscaler add-on and its IAM policies."
  type        = bool
  default     = true
}

# --- Networking ---
variable "vcn_cidr" {
  description = "CIDR for the VCN."
  type        = string
  default     = "10.240.0.0/16"
}

variable "services_cidr" {
  description = "CIDR for ClusterIP services."
  type        = string
  default     = "10.96.0.0/16"
}

variable "pods_cidr" {
  description = "CIDR for Pod IPs (used by the autoscaler / CNI)."
  type        = string
  default     = "10.244.0.0/16"
}

variable "lb_ingress_cidrs" {
  description = "CIDRs allowed to reach the LoadBalancer NSG (443/80)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_endpoint_ingress_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API endpoint (6443)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_oke_service_policy" {
  description = "Create the tenancy-level policy granting OKE permission to manage the compartment."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Common labels/tags applied to created resources."
  type        = map(string)
  default = {
    "oci:tags" = "oci-full-stack"
  }
}
