provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ── Look up the VCN to get its default security list OCID ───────────────────
data "oci_core_vcn" "existing" {
  vcn_id = var.vcn_ocid
}

# ── Manage the VCN's default security list (already attached to all subnets) ─
# Uses the OCI terraform provider directly — no OCI CLI required.
# We open all required ports and preserve standard Oracle ICMP defaults.
resource "oci_core_default_security_list" "k3s" {
  manage_default_resource_id = data.oci_core_vcn.existing.default_security_list_id

  ingress_security_rules {
    description = "SSH"
    protocol    = "6"
    source      = var.allowed_ssh_cidr
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    description = "k3s API server (GitHub Actions OIDC + kubectl)"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "HTTP"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "HTTPS"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    description = "NodePort: production frontend"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 30080
      max = 30080
    }
  }

  ingress_security_rules {
    description = "NodePort: staging frontend"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 30180
      max = 30180
    }
  }

  ingress_security_rules {
    description = "NodePort: Grafana"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 30300
      max = 30300
    }
  }

  ingress_security_rules {
    description = "NodePort: ArgoCD"
    protocol    = "6"
    source      = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 30443
      max = 30443
    }
  }

  # ICMP path MTU discovery (required for proper TCP on Oracle Cloud)
  ingress_security_rules {
    description = "ICMP path MTU"
    protocol    = "1"
    source      = "0.0.0.0/0"
    stateless   = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  # ICMP ping from VCN (standard Oracle default)
  ingress_security_rules {
    description = "ICMP ping from VCN"
    protocol    = "1"
    source      = "10.0.0.0/8"
    stateless   = false
    icmp_options {
      type = 8
    }
  }

  egress_security_rules {
    description = "Allow all outbound"
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# ── k3s bootstrap: install k3s + ArgoCD on the existing VM via SSH ──────────
module "k3s_bootstrap" {
  source          = "./modules/k3s-bootstrap"
  vm_public_ip    = var.vm_public_ip
  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_private_key
  k3s_version     = var.k3s_version
  github_repo     = var.github_repo

  depends_on = [oci_core_default_security_list.k3s]
}
