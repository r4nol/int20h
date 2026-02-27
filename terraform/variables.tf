variable "tenancy_ocid" {
  type        = string
  description = "OCID of the OCI tenancy"
}

variable "user_ocid" {
  type        = string
  description = "OCID of the OCI user for API authentication"
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint of the API key uploaded to OCI"
}

variable "private_key_path" {
  type        = string
  description = "Path to the OCI API private key file"
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  type        = string
  description = "OCI region (e.g. eu-frankfurt-1, us-ashburn-1)"
}

variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment to manage resources in"
}

variable "vcn_ocid" {
  type        = string
  description = "OCID of the existing VCN where the VM resides"
}

variable "subnet_ocid" {
  type        = string
  description = "OCID of the existing public subnet where the VM resides"
}

variable "vm_display_name" {
  type        = string
  description = "Display name of the existing Oracle VM instance"
  default     = "int20h-k3s"
}

variable "vm_public_ip" {
  type        = string
  description = "Public IP address of the existing Oracle VM"
}

variable "ssh_user" {
  type        = string
  description = "SSH user for the Oracle VM (ubuntu for Ubuntu, opc for Oracle Linux)"
  default     = "ubuntu"
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "SSH private key content for connecting to the VM"
}

variable "k3s_version" {
  type        = string
  description = "k3s version to install (e.g. v1.30.0+k3s1)"
  default     = "v1.30.0+k3s1"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository in owner/name format (e.g. myorg/int20h)"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR block allowed to SSH to the VM (restrict to your IP for security)"
  default     = "0.0.0.0/0"
}
