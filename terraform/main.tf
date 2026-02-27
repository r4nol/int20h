provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ── Security module: open required ports on the subnet ──────────────────────
module "oci_security" {
  source           = "./modules/oci-security"
  compartment_id   = var.compartment_ocid
  vcn_id           = var.vcn_ocid
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# ── Attach the new security list to the existing subnet ─────────────────────
resource "oci_core_subnet" "k3s_subnet" {
  # We import the existing subnet and add our security list to it.
  # Using lifecycle.ignore_changes to prevent Terraform from resetting
  # other subnet attributes managed outside of Terraform.
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  cidr_block     = "0.0.0.0/0" # placeholder - use `terraform import` with actual subnet

  security_list_ids = [module.oci_security.security_list_id]

  lifecycle {
    # Never destroy the existing subnet - only manage security_list_ids
    prevent_destroy = true
    ignore_changes = [
      cidr_block,
      display_name,
      dns_label,
      route_table_id,
      dhcp_options_id,
      prohibit_public_ip_on_vnic,
    ]
  }
}

# ── k3s bootstrap: install k3s + ArgoCD on the existing VM ──────────────────
module "k3s_bootstrap" {
  source          = "./modules/k3s-bootstrap"
  vm_public_ip    = var.vm_public_ip
  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_private_key
  k3s_version     = var.k3s_version
  github_repo     = var.github_repo

  depends_on = [module.oci_security]
}
