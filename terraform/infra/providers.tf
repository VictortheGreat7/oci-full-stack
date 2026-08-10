terraform {
  required_version = ">= 1.5"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

# The OCI provider authenticates using, in order:
#   1. OCI_* environment variables (e.g. OCI_TENANCY_OCID, OCI_USER_OCID,
#      OCI_FINGERPRINT, OCI_PRIVATE_KEY_PATH, OCI_REGION)
#   2. $HOME/.oci/config (DEFAULT profile)
# No arguments are required here, so the same code works both locally
# (with an existing ~/.oci/config) and in CI (with OCI_* env vars set).
provider "oci" {}
