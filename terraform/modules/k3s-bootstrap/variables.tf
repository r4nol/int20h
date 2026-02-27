variable "vm_public_ip" {
  type        = string
  description = "Public IP of the Oracle VM"
}

variable "ssh_user" {
  type        = string
  description = "SSH username (ubuntu or opc)"
  default     = "ubuntu"
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "SSH private key content"
}

variable "k3s_version" {
  type        = string
  description = "k3s version string"
  default     = "v1.30.0+k3s1"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository (owner/name) for OIDC binding"
}
