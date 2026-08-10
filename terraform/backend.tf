terraform {
  required_version = ">= 1.5"

  cloud {
    organization = "VictortheGreat7-TF"
    workspaces {
      name = "oci-full-stack"
    }
  }
}
