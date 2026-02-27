locals {
  # Detect re-runs: changing k3s_version or script triggers re-install
  install_trigger_hash = sha256("${var.k3s_version}-${var.github_repo}")
}

# ── Step 1: Install k3s with OIDC API server flags ──────────────────────────
resource "null_resource" "k3s_install" {
  triggers = {
    version     = var.k3s_version
    github_repo = var.github_repo
    script_hash = filemd5("${path.module}/scripts/install-k3s.sh")
  }

  connection {
    type        = "ssh"
    host        = var.vm_public_ip
    user        = var.ssh_user
    private_key = var.ssh_private_key
    timeout     = "10m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-k3s.sh"
    destination = "/tmp/install-k3s.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-k3s.sh",
      "sudo /tmp/install-k3s.sh '${var.k3s_version}' '${var.github_repo}'",
    ]
  }
}

# ── Step 2: Install ArgoCD + bootstrap root Application ─────────────────────
resource "null_resource" "argocd_bootstrap" {
  triggers = {
    k3s_id      = null_resource.k3s_install.id
    script_hash = filemd5("${path.module}/scripts/install-argocd.sh")
  }

  depends_on = [null_resource.k3s_install]

  connection {
    type        = "ssh"
    host        = var.vm_public_ip
    user        = var.ssh_user
    private_key = var.ssh_private_key
    timeout     = "15m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-argocd.sh"
    destination = "/tmp/install-argocd.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-argocd.sh",
      "sudo /tmp/install-argocd.sh",
    ]
  }
}
