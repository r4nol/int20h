terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # Use the canonical oracle/oci provider (moved from hashicorp/oci in 2022)
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
