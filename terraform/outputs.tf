output "kubeconfig" {
    value = local.kubeconfig_content
    sensitive = true
}
