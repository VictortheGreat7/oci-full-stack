terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 8.27.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.14.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.3.0"
    }
  }
}

# The OCI provider authenticates using, in order:
#   1. Provider arguments below (fed from Terraform Cloud workspace variables)
#   2. OCI_* environment variables (e.g. OCI_TENANCY_OCID, OCI_USER_OCID,
#      OCI_FINGERPRINT, OCI_PRIVATE_KEY_PATH, OCI_REGION)
#   3. $HOME/.oci/config (DEFAULT profile)
# Arguments are only set when supplied, so the same code works locally
# (with an existing ~/.oci/config) and in HCP Terraform Cloud (with the
# oci_* variables configured as sensitive workspace variables).
provider "oci" {
  tenancy_ocid     = var.oci_tenancy_ocid != "" ? var.oci_tenancy_ocid : null
  user_ocid        = var.oci_user_ocid != "" ? var.oci_user_ocid : null
  fingerprint      = var.oci_fingerprint != "" ? var.oci_fingerprint : null
  private_key      = var.oci_private_key != "" ? var.oci_private_key : null
  private_key_path = var.oci_private_key_path != "" ? var.oci_private_key_path : null
  region           = var.oci_region != "" ? var.oci_region : null
}

# Required by the oke module for IAM resources that must be created in the home region
provider "oci" {
  alias            = "home"
  tenancy_ocid     = var.oci_tenancy_ocid != "" ? var.oci_tenancy_ocid : null
  user_ocid        = var.oci_user_ocid != "" ? var.oci_user_ocid : null
  fingerprint      = var.oci_fingerprint != "" ? var.oci_fingerprint : null
  private_key      = var.oci_private_key != "" ? var.oci_private_key : null
  private_key_path = var.oci_private_key_path != "" ? var.oci_private_key_path : null
  region           = var.oci_region != "" ? var.oci_region : null
}
