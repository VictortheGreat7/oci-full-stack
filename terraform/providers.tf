terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.3.0"
    }
  }
}

# The kubeconfig is produced by the infra module (terraform/infra) and written
# to terraform/kubeconfig. It uses an `exec` plugin backed by the OCI CLI, so
# oci-cli must be installed and authenticated wherever Terraform runs.
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}
