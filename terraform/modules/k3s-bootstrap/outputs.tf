output "k3s_install_id" {
  description = "ID of the k3s install null_resource (used as trigger)"
  value       = null_resource.k3s_install.id
}

output "argocd_bootstrap_id" {
  description = "ID of the ArgoCD bootstrap null_resource"
  value       = null_resource.argocd_bootstrap.id
}
