resource "oci_core_security_list" "k3s" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "k3s-int20h-security-list"

  # ── Inbound rules ──────────────────────────────────────────────────────────

  # SSH - restrict to your IP in production (see allowed_ssh_cidr variable)
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allowed_ssh_cidr
    description = "SSH access"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Kubernetes API server - needed for GitHub Actions OIDC kubectl calls
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "K8s API server (GitHub Actions OIDC auth)"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # HTTP (for cert-manager HTTP-01 challenge if added later)
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTP"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "HTTPS"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Production frontend NodePort
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Online Boutique - Production frontend"
    tcp_options {
      min = 30080
      max = 30080
    }
  }

  # Staging frontend NodePort
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Online Boutique - Staging frontend"
    tcp_options {
      min = 30180
      max = 30180
    }
  }

  # Grafana NodePort
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "Grafana dashboards"
    tcp_options {
      min = 30300
      max = 30300
    }
  }

  # ArgoCD NodePort (HTTPS)
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    description = "ArgoCD UI"
    tcp_options {
      min = 30443
      max = 30443
    }
  }

  # ── Outbound rules ─────────────────────────────────────────────────────────
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound (image pulls, DNS, etc.)"
  }
}
