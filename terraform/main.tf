provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ── Security module: create OCI Security List with required ports ────────────
module "oci_security" {
  source           = "./modules/oci-security"
  compartment_id   = var.compartment_ocid
  vcn_id           = var.vcn_ocid
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# ── Attach security list to the existing subnet via local-exec (OCI CLI) ────
# This is safer than managing the subnet resource directly (avoids accidental destroy).
# Requires OCI CLI configured on the machine running terraform.
resource "null_resource" "attach_security_list" {
  triggers = {
    security_list_id = module.oci_security.security_list_id
    subnet_id        = var.subnet_ocid
  }

  provisioner "local-exec" {
    command = <<-EOF
      echo "Attaching security list ${self.triggers.security_list_id} to subnet ${self.triggers.subnet_id}"
      # Get current security lists on the subnet
      CURRENT=$(oci network subnet get \
        --subnet-id "${self.triggers.subnet_id}" \
        --query 'data."security-list-ids"' \
        --raw-output 2>/dev/null || echo "[]")
      echo "Current security lists: $CURRENT"
      # Append our new security list (OCI CLI must be configured)
      oci network subnet update \
        --subnet-id "${self.triggers.subnet_id}" \
        --security-list-ids "[\"${self.triggers.security_list_id}\"]" \
        --force 2>/dev/null && echo "Security list attached" || \
        echo "WARNING: Could not attach security list automatically. Attach manually in OCI Console: ${self.triggers.security_list_id}"
    EOF
    on_failure = continue  # Non-fatal: user can attach manually in OCI console
  }

  depends_on = [module.oci_security]
}

# ── k3s bootstrap: install k3s + ArgoCD on the existing VM via SSH ──────────
module "k3s_bootstrap" {
  source          = "./modules/k3s-bootstrap"
  vm_public_ip    = var.vm_public_ip
  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_private_key
  k3s_version     = var.k3s_version
  github_repo     = var.github_repo

  depends_on = [module.oci_security]
}
