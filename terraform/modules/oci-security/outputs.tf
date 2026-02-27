output "security_list_id" {
  description = "OCID of the created security list"
  value       = oci_core_security_list.k3s.id
}
