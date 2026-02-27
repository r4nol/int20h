variable "compartment_id" {
  type        = string
  description = "OCI compartment OCID"
}

variable "vcn_id" {
  type        = string
  description = "OCI VCN OCID"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to SSH. Use your IP for security."
  default     = "0.0.0.0/0"
}
