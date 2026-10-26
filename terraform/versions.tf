terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
  }
}

# Authentication comes from ~/.oci/config (created by `oci setup config`).
provider "oci" {
  region              = var.region
  config_file_profile = var.oci_config_profile
}
