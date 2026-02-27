output "vm_public_ip" {
  description = "Public IP of the k3s node"
  value       = var.vm_public_ip
}

output "k8s_api_server" {
  description = "Kubernetes API server endpoint"
  value       = "https://${var.vm_public_ip}:6443"
}

output "frontend_production_url" {
  description = "URL for the production Online Boutique frontend"
  value       = "http://${var.vm_public_ip}:30080"
}

output "frontend_staging_url" {
  description = "URL for the staging Online Boutique frontend"
  value       = "http://${var.vm_public_ip}:30180"
}

output "argocd_url" {
  description = "ArgoCD UI URL"
  value       = "https://${var.vm_public_ip}:30443"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://${var.vm_public_ip}:30300"
}

output "next_steps" {
  description = "Post-deployment steps"
  value       = <<-EOF
    Infrastructure deployed. Next steps:
    1. Add GitHub Actions secret K8S_SERVER = https://${var.vm_public_ip}:6443
    2. Bootstrap ArgoCD root app:
       ssh ${var.ssh_user}@${var.vm_public_ip} kubectl apply -f /tmp/argocd-root-app.yaml
    3. Verify: kubectl get nodes
    4. Open ArgoCD UI: https://${var.vm_public_ip}:30443
       Password: kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  EOF
}
