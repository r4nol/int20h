terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # Uncomment to use OCI Object Storage as remote backend
  # (S3-compatible API)
  # backend "s3" {
  #   endpoint                    = "https://<namespace>.compat.objectstorage.<region>.oraclecloud.com"
  #   bucket                      = "terraform-state-int20h"
  #   key                         = "k3s/terraform.tfstate"
  #   region                      = "us-ashburn-1"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   force_path_style            = true
  # }
}
