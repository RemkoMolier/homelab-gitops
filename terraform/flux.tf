data "flux_install" "cluster" {
  namespace = var.flux_namespace
  target_path = var.flux_target_path
  cluster_domain = var.cluster_domain
}

resource "local_file" "gotk_components_yaml" {
  content = data.flux_install.cluster.content
  filename = "../${data.flux_install.cluster.path}"
}

#data "flux_sync" "cluster" {
#  namespace   = var.flux_namespace
#  secret      = var.repository_name
#  target_path = var.flux_target_path
#  url         = "ssh://git@github.com/${var.repository_owner}/${var.repository_name}.git"
#  branch      = var.repository_branch
#}

resource "local_file" "ks_yaml" {
  content = templatefile("./flux/kustomization.tftpl",{ namespace = var.flux_namespace, path = var.flux_target_path, repository_name = var.repository_name})
  filename = "../${var.flux_target_path}/${var.flux_namespace}/ks.yaml"
}

resource "local_file" "gitrepository_yaml" {
  content = templatefile("./flux/gitrepository.tftpl",{ namespace = var.flux_namespace, name = var.repository_name, secret = var.repository_name, url = "ssh://git@github.com/${var.repository_owner}/${var.repository_name}.git", branch = var.repository_branch })
  filename = "../${var.flux_target_path}/${var.flux_namespace}/repositories/git/${var.repository_name}.yaml"
}


locals {
  github_known_hosts = <<EOT
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
  EOT
}

resource "remote_file" "gotk_components_yaml" {
  conn {
      host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
      user        = "debian"
      private_key = tls_private_key.ssh_key.private_key_openssh
  }

  content = file("../cluster/flux-system/gotk-components.yaml")
  path = "/home/debian/gotk-components.yaml"
  
}

resource "remote_file" "ks_yaml" {
  conn {
      host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
      user        = "debian"
      private_key = tls_private_key.ssh_key.private_key_openssh
  }

  content = file("../cluster/flux-system/ks.yaml")
  path = "/home/debian/ks.yaml"
}

resource "remote_file" "gitrepository_yaml" {
  conn {
      host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
      user        = "debian"
      private_key = tls_private_key.ssh_key.private_key_openssh
  }

  content = file("../cluster/flux-system/repositories/git/${var.repository_name}.yaml")
  path = "/home/debian/gitrepository.yaml"
}



resource "null_resource" "k3s_server_flux_init" {
    count = length(proxmox_vm_qemu.k3s_server) > 0 ? 1:0
    
    connection {
        user = "debian"
        host = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
        private_key = tls_private_key.ssh_key.private_key_openssh
        timeout = "20m"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo kubectl create namespace ${var.flux_namespace} --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl -n ${var.flux_namespace} create secret generic sops-age --from-literal=age.ageKey='${data.sops_file.secrets.data["age.agekey"]}' --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl -n ${var.flux_namespace} create secret generic ${var.repository_name} --from-literal=identity='${data.sops_file.secrets.data["git.deploy-key.private"]}' --from-literal=identity.pub='${data.sops_file.secrets.data["git.deploy-key.public"]}' --from-literal=known_hosts='${local.github_known_hosts}' --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl apply -f /home/debian/gotk-components.yaml",
            "sudo kubectl apply -f /home/debian/gitrepository.yaml",
            "sudo kubectl apply -f /home/debian/ks.yaml"
            
        ]
    }

    depends_on = [
        null_resource.k3s_server_cluster_init,
        remote_file.gotk_components_yaml,
        remote_file.gitrepository_yaml,
        remote_file.ks_yaml
    ]
}